#!/usr/bin/env python3
"""SSM: run scrub-ssh.sh on the builder, then Terraform may stop the instance."""
import json
import os
import subprocess
import sys
import tempfile


def main() -> None:
    instance_id = os.environ["ABSI_INSTANCE_ID"]
    region = os.environ["AWS_REGION"]
    script_path = os.environ["ABSI_SCRUB_SCRIPT"]
    script = open(script_path, encoding="utf-8").read()
    params = tempfile.NamedTemporaryFile("w", delete=False, suffix=".json")
    json.dump({"commands": [script]}, params)
    params.close()

    cmd_id = subprocess.check_output(
        [
            "aws",
            "ssm",
            "send-command",
            "--region",
            region,
            "--instance-ids",
            instance_id,
            "--document-name",
            "AWS-RunShellScript",
            "--timeout-seconds",
            "120",
            "--parameters",
            f"file://{params.name}",
            "--query",
            "Command.CommandId",
            "--output",
            "text",
        ],
        text=True,
    ).strip()
    try:
        subprocess.check_call(
            [
                "aws",
                "ssm",
                "wait",
                "command-executed",
                "--region",
                region,
                "--command-id",
                cmd_id,
                "--instance-id",
                instance_id,
            ]
        )
    except subprocess.CalledProcessError:
        pass
    inv = json.loads(
        subprocess.check_output(
            [
                "aws",
                "ssm",
                "get-command-invocation",
                "--region",
                region,
                "--command-id",
                cmd_id,
                "--instance-id",
                instance_id,
                "--output",
                "json",
            ],
            text=True,
        )
    )
    sys.stderr.write(inv.get("StandardOutputContent") or "")
    sys.stderr.write(inv.get("StandardErrorContent") or "")
    if inv.get("Status") != "Success":
        sys.exit(
            f"authorized_keys scrub failed: {inv.get('Status')} {inv.get('StatusDetails')}"
        )


if __name__ == "__main__":
    main()
