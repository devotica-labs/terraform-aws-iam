#!/usr/bin/env python3
"""Render an IAM topology diagram from a Terraform plan JSON.

Reads the output of `terraform show -json plan.binary` from the
`examples/complete/` plan, maps each planned AWS IAM resource to its
`diagrams.aws.*` icon, groups roles by trust_type (service vs. AWS
principal / cross-account), and writes a PNG.

This script is invoked from `.github/workflows/architecture-diagram.yml`
on every PR and on push to main. The committed PNG lives at
`docs/architecture.png` and is embedded in README.md between
`<!-- BEGIN_ARCH -->` / `<!-- END_ARCH -->` markers.

Usage:
    python scripts/render-architecture.py <plan.json> <output-path-no-ext>

Example:
    python scripts/render-architecture.py examples/complete/plan.json docs/architecture
        -> writes docs/architecture.png
"""

from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2, ECS, Lambda
from diagrams.aws.general import General, Users
from diagrams.aws.management import SystemsManager
from diagrams.aws.security import (
    IAM,
    IAMAccessAnalyzer,
    IAMAWSSts,
    IAMPermissions,
    IAMRole,
)


# ----------------------------------------------------------------------------
# Resource collection
# ----------------------------------------------------------------------------


def load_resources(plan_path: Path) -> list[dict]:
    """Flatten every resource (root + child modules) from a Terraform plan JSON."""
    plan = json.loads(plan_path.read_text())
    root = plan.get("planned_values", {}).get("root_module", {})
    collected: list[dict] = []

    def walk(mod: dict) -> None:
        for r in mod.get("resources", []):
            collected.append(r)
        for child in mod.get("child_modules", []):
            walk(child)

    walk(root)
    return collected


def values(r: dict) -> dict:
    return r.get("values", {}) or {}


def role_key(addr: str) -> str:
    """Extract the role map key from a Terraform address like
    `module.iam.aws_iam_role.this["lambda-exec"]` → `lambda-exec`."""
    m = re.search(r'\["([^"]+)"\]', addr)
    return m.group(1) if m else addr


# ----------------------------------------------------------------------------
# Trust-policy parsing
# ----------------------------------------------------------------------------


SERVICE_ICON = {
    "lambda.amazonaws.com": Lambda,
    "ec2.amazonaws.com": EC2,
    "ecs-tasks.amazonaws.com": ECS,
    "ecs.amazonaws.com": ECS,
    "ssm.amazonaws.com": SystemsManager,
}


def classify_role(role_values: dict) -> tuple[str, list[str]]:
    """Return (trust_type, principals).

    trust_type ∈ {"service", "aws", "unknown"} based on the assume_role_policy
    JSON. We only need a coarse classification for grouping in the diagram.
    """
    policy = role_values.get("assume_role_policy")
    if not policy:
        return ("unknown", [])
    try:
        doc = json.loads(policy)
    except json.JSONDecodeError:
        return ("unknown", [])

    statements = doc.get("Statement", [])
    if isinstance(statements, dict):
        statements = [statements]

    for stmt in statements:
        principal = stmt.get("Principal", {}) or {}
        if "Service" in principal:
            svc = principal["Service"]
            return ("service", svc if isinstance(svc, list) else [svc])
        if "AWS" in principal:
            aws = principal["AWS"]
            return ("aws", aws if isinstance(aws, list) else [aws])
    return ("unknown", [])


# ----------------------------------------------------------------------------
# Render
# ----------------------------------------------------------------------------


def render(plan_path: Path, out_no_ext: Path) -> None:
    resources = load_resources(plan_path)
    by_type: dict[str, list[dict]] = defaultdict(list)
    for r in resources:
        by_type[r["type"]].append(r)

    roles = by_type.get("aws_iam_role", [])
    if not roles:
        raise SystemExit("No aws_iam_role resource found in plan — nothing to render.")

    # role_key -> { values, trust_type, principals, address }
    role_index: dict[str, dict] = {}
    for r in roles:
        k = role_key(r["address"])
        v = values(r)
        tt, principals = classify_role(v)
        role_index[k] = {
            "values": v,
            "trust_type": tt,
            "principals": principals,
            "address": r["address"],
        }

    # role_key -> [managed_policy_arn, ...]
    managed_by_role: dict[str, list[str]] = defaultdict(list)
    for r in by_type.get("aws_iam_role_policy_attachment", []):
        v = values(r)
        # Address: ...aws_iam_role_policy_attachment.managed["<role_key>::<arn>"]
        m = re.search(r'\["([^:]+)::', r["address"])
        if m:
            managed_by_role[m.group(1)].append(v.get("policy_arn", ""))

    # role_key -> [inline_policy_name, ...]
    inline_by_role: dict[str, list[str]] = defaultdict(list)
    for r in by_type.get("aws_iam_role_policy", []):
        v = values(r)
        m = re.search(r'\["([^:]+)::', r["address"])
        if m:
            inline_by_role[m.group(1)].append(v.get("name", "inline"))

    # role_key -> instance_profile name
    instance_profile_by_role: dict[str, str] = {}
    for r in by_type.get("aws_iam_instance_profile", []):
        k = role_key(r["address"])
        instance_profile_by_role[k] = values(r).get("name", k)

    has_password_policy = bool(by_type.get("aws_iam_account_password_policy"))
    has_alias = bool(by_type.get("aws_iam_account_alias"))
    alias_value = ""
    if has_alias:
        alias_value = values(by_type["aws_iam_account_alias"][0]).get("account_alias", "")
    has_analyzer = bool(by_type.get("aws_accessanalyzer_analyzer"))
    analyzer_name = ""
    if has_analyzer:
        analyzer_name = values(by_type["aws_accessanalyzer_analyzer"][0]).get(
            "analyzer_name", ""
        )

    service_roles = {k: r for k, r in role_index.items() if r["trust_type"] == "service"}
    aws_roles = {k: r for k, r in role_index.items() if r["trust_type"] == "aws"}

    # ------------------------------------------------------------------------
    # Diagram
    # ------------------------------------------------------------------------
    graph_attr = {
        "fontsize": "20",
        "splines": "ortho",
        "ranksep": "0.9",
        "nodesep": "0.45",
        "pad": "0.5",
    }
    title = "terraform-aws-iam"
    if alias_value:
        title = f"{title} — {alias_value}"

    out_no_ext.parent.mkdir(parents=True, exist_ok=True)
    with Diagram(
        title,
        filename=str(out_no_ext),
        show=False,
        direction="LR",
        outformat="png",
        graph_attr=graph_attr,
    ):
        # ── Service execution roles (Lambda/EC2/ECS/EKS/…) ─────────────────
        if service_roles:
            with Cluster("Service execution roles"):
                for k, info in sorted(service_roles.items()):
                    service_id = (info["principals"] or ["unknown"])[0]
                    SvcIcon = SERVICE_ICON.get(service_id, IAMRole)
                    caller = SvcIcon(service_id.split(".")[0])

                    role_node = IAMRole(info["values"].get("name", k))
                    caller >> Edge(label="sts:AssumeRole") >> role_node

                    # Managed policies
                    for arn in managed_by_role.get(k, []):
                        short = arn.split("/")[-1] or arn
                        role_node >> Edge(style="dashed") >> IAMPermissions(short)

                    # Inline policies
                    for pname in inline_by_role.get(k, []):
                        role_node >> Edge(style="dotted", label="inline") >> IAMPermissions(pname)

                    # Instance profile (EC2 only)
                    if k in instance_profile_by_role:
                        role_node >> Edge(label="instance-profile") >> EC2(
                            instance_profile_by_role[k]
                        )

        # ── Cross-account / AWS principal roles ────────────────────────────
        if aws_roles:
            with Cluster("Cross-account assume roles"):
                for k, info in sorted(aws_roles.items()):
                    # Trust originator — group by account ID for readability.
                    label_lines = []
                    for arn in info["principals"][:2]:
                        m = re.match(r"arn:aws:iam::(\d+):", arn)
                        if m:
                            label_lines.append(f"acct {m.group(1)}")
                        else:
                            label_lines.append(arn[:30])
                    caller = Users("\n".join(label_lines) or "external")

                    role_node = IAMRole(info["values"].get("name", k))

                    edge_label = "sts:AssumeRole"
                    # Inspect the trust policy for MFA / ExternalId condition keys.
                    try:
                        doc = json.loads(info["values"].get("assume_role_policy", "{}"))
                        stmts = doc.get("Statement", [])
                        if isinstance(stmts, dict):
                            stmts = [stmts]
                        for s in stmts:
                            cond = s.get("Condition", {}) or {}
                            flags = []
                            for vals in cond.values():
                                if isinstance(vals, dict):
                                    if "aws:MultiFactorAuthPresent" in vals:
                                        flags.append("MFA")
                                    if "sts:ExternalId" in vals:
                                        flags.append("ExternalId")
                            if flags:
                                edge_label = f"sts:AssumeRole\n({' + '.join(sorted(set(flags)))})"
                    except json.JSONDecodeError:
                        pass

                    caller >> Edge(label=edge_label) >> role_node

                    for arn in managed_by_role.get(k, []):
                        short = arn.split("/")[-1] or arn
                        role_node >> Edge(style="dashed") >> IAMPermissions(short)
                    for pname in inline_by_role.get(k, []):
                        role_node >> Edge(style="dotted", label="inline") >> IAMPermissions(pname)

        # ── Account baseline ────────────────────────────────────────────────
        if has_password_policy or has_alias or has_analyzer:
            with Cluster("Account baseline"):
                if has_password_policy:
                    IAM("Password Policy\n(CIS-aligned)")
                if has_alias:
                    General(f"Alias\n{alias_value}")
                if has_analyzer:
                    IAMAccessAnalyzer(f"Access Analyzer\n{analyzer_name}")


def main() -> None:
    if len(sys.argv) < 3:
        sys.stderr.write(
            "Usage: render-architecture.py <plan.json> <output-path-without-ext>\n"
        )
        sys.exit(2)
    render(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
