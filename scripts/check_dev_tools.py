#!/usr/bin/env python3
"""
Development tools checker for Radial Menu project.
Outputs structured JSON with tool availability and system information.
"""

import json
import subprocess
import platform
import shutil
import os
import sys
import argparse
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass, asdict
from enum import Enum


class ToolStatus(Enum):
    FOUND = "found"
    NOT_FOUND = "not_found"
    ERROR = "error"
    WARNING = "warning"


class ToolCategory(Enum):
    REQUIRED = "required"
    OPTIONAL = "optional"
    PROJECT_SPECIFIC = "project-specific"


class CheckType(Enum):
    COMMAND = "command"
    DIRECTORY = "directory"
    FRAMEWORK = "framework"
    XCODE_SPECIAL = "xcode_special"
    CUSTOM = "custom"


@dataclass
class Issue:
    level: str  # error, warning, info
    message: str
    fix: Optional[str] = None


@dataclass
class Installation:
    method: str
    command: Optional[str] = None
    url: Optional[str] = None
    notes: Optional[str] = None


@dataclass
class ToolResult:
    id: str
    name: str
    category: str
    status: str
    installed: bool
    working: bool
    version: Optional[str] = None
    path: Optional[str] = None
    check_type: str = "command"
    issues: List[Dict] = None
    installation: Optional[Dict] = None

    def __post_init__(self):
        if self.issues is None:
            self.issues = []


class DevToolsChecker:
    def __init__(self, config_path: Optional[Path] = None):
        self.config_path = config_path or Path(__file__).parent / "tools_config.json"
        self.config = self.load_config()
        self.results = []
        self.system_info = self.get_system_info()

    def load_config(self) -> Dict:
        """Load tool configuration from JSON file."""
        if self.config_path.exists():
            with open(self.config_path, 'r') as f:
                return json.load(f)
        else:
            # Return default configuration if file doesn't exist
            return self.get_default_config()

    def get_default_config(self) -> Dict:
        """Return default tool configuration if config file doesn't exist."""
        # This is a fallback - the actual config will be in tools_config.json
        return {
            "version": "1.0.0",
            "tools": [],
            "system_requirements": {
                "min_macos_version": "13.0",
                "supported_architectures": ["arm64", "x86_64"]
            }
        }

    def run_command(self, command: List[str], check_error: bool = False) -> Tuple[bool, str, str]:
        """Run a command and return success, stdout, stderr."""
        try:
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=5
            )
            success = result.returncode == 0 if check_error else True
            return success, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return False, "", "Command timed out"
        except FileNotFoundError:
            return False, "", "Command not found"
        except Exception as e:
            return False, "", str(e)

    def check_command(self, command: str, version_flag: str = "--version",
                     version_regex: Optional[str] = None) -> Tuple[bool, Optional[str], Optional[str]]:
        """Check if a command exists and get its version."""
        # First check if command exists
        cmd_path = shutil.which(command)
        if not cmd_path:
            return False, None, None

        # Try to get version
        success, stdout, stderr = self.run_command([command, version_flag])
        if not success:
            # Some tools output version to stderr or use different flags
            if stderr:
                output = stderr
            else:
                # Try alternative version flags
                for flag in ["-v", "version", "-version", "--version"]:
                    success, stdout, stderr = self.run_command([command, flag])
                    if success or stdout or stderr:
                        output = stdout if stdout else stderr
                        break
                else:
                    return True, None, cmd_path  # Command exists but version unknown
        else:
            output = stdout if stdout else stderr

        # Extract version
        version = self.extract_version(output, version_regex)
        return True, version, cmd_path

    def extract_version(self, output: str, regex: Optional[str] = None) -> Optional[str]:
        """Extract version from command output."""
        if not output:
            return None

        if regex:
            match = re.search(regex, output)
            if match:
                return match.group(1) if match.groups() else match.group(0)

        # Default patterns
        patterns = [
            r'(\d+\.\d+\.\d+)',
            r'version (\d+\.\d+)',
            r'v(\d+\.\d+\.\d+)',
        ]

        for pattern in patterns:
            match = re.search(pattern, output, re.IGNORECASE)
            if match:
                return match.group(1)

        return None

    def check_xcode(self) -> ToolResult:
        """Special check for Xcode installation and configuration."""
        xcode_app = Path("/Applications/Xcode.app")
        issues = []

        # Get xcode-select path
        success, stdout, stderr = self.run_command(["xcode-select", "-p"])
        xcode_select_path = stdout.strip() if success else None

        # Check if Xcode.app exists
        if xcode_app.exists():
            if xcode_select_path and "Xcode.app" in xcode_select_path:
                # Xcode is installed and selected, check if it works
                success, stdout, stderr = self.run_command(["xcodebuild", "-version"], check_error=True)
                if success:
                    version = self.extract_version(stdout)

                    # Check for first launch
                    first_launch_success, _, _ = self.run_command(
                        ["xcodebuild", "-checkFirstLaunchStatus"],
                        check_error=True
                    )
                    if not first_launch_success:
                        issues.append({
                            "level": "warning",
                            "message": "Xcode may need to complete first launch setup",
                            "fix": "sudo xcodebuild -runFirstLaunch"
                        })

                    return ToolResult(
                        id="xcode",
                        name="Xcode",
                        category="required",
                        status="found" if not issues else "warning",
                        installed=True,
                        working=True,
                        version=version,
                        path=xcode_select_path,
                        check_type="xcode_special",
                        issues=issues
                    )
                else:
                    issues.append({
                        "level": "error",
                        "message": "Xcode is installed but xcodebuild doesn't work",
                        "fix": f"Check Xcode installation at {xcode_app}"
                    })
            else:
                # Xcode.app exists but not selected
                issues.append({
                    "level": "error",
                    "message": f"Xcode.app exists but not selected (current: {xcode_select_path})",
                    "fix": "sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
                })
                return ToolResult(
                    id="xcode",
                    name="Xcode",
                    category="required",
                    status="error",
                    installed=True,
                    working=False,
                    path=str(xcode_app),
                    check_type="xcode_special",
                    issues=issues,
                    installation={
                        "method": "Fix selection",
                        "command": "sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
                    }
                )
        elif xcode_select_path and "CommandLineTools" in xcode_select_path:
            # Only Command Line Tools installed
            issues.append({
                "level": "error",
                "message": "Only Command Line Tools installed, full Xcode required",
                "fix": "Download Xcode from Mac App Store"
            })
            return ToolResult(
                id="xcode",
                name="Xcode",
                category="required",
                status="not_found",
                installed=False,
                working=False,
                check_type="xcode_special",
                issues=issues,
                installation={
                    "method": "Mac App Store",
                    "url": "https://apps.apple.com/us/app/xcode/id497799835",
                    "notes": "Full Xcode installation required for building macOS apps"
                }
            )
        else:
            # No Xcode at all
            return ToolResult(
                id="xcode",
                name="Xcode",
                category="required",
                status="not_found",
                installed=False,
                working=False,
                check_type="xcode_special",
                issues=[{
                    "level": "error",
                    "message": "Xcode not installed",
                    "fix": "Download from Mac App Store or https://developer.apple.com"
                }],
                installation={
                    "method": "Mac App Store",
                    "url": "https://apps.apple.com/us/app/xcode/id497799835"
                }
            )

    def check_xcode_clt(self) -> ToolResult:
        """Check Xcode Command Line Tools."""
        success, stdout, _ = self.run_command(["xcode-select", "-p"])
        if success and stdout.strip():
            path = stdout.strip()
            return ToolResult(
                id="xcode_clt",
                name="Xcode Command Line Tools",
                category="required",
                status="found",
                installed=True,
                working=True,
                path=path,
                check_type="directory"
            )
        else:
            return ToolResult(
                id="xcode_clt",
                name="Xcode Command Line Tools",
                category="required",
                status="not_found",
                installed=False,
                working=False,
                check_type="directory",
                issues=[{
                    "level": "error",
                    "message": "Command Line Tools not installed",
                    "fix": "xcode-select --install"
                }],
                installation={
                    "method": "xcode-select",
                    "command": "xcode-select --install"
                }
            )

    def check_xcodebuild(self) -> ToolResult:
        """Check if xcodebuild actually works."""
        success, stdout, stderr = self.run_command(["xcodebuild", "-version"], check_error=True)
        if success:
            version = self.extract_version(stdout)
            return ToolResult(
                id="xcodebuild",
                name="xcodebuild",
                category="required",
                status="found",
                installed=True,
                working=True,
                version=version,
                check_type="command"
            )
        else:
            issues = []
            installation = None

            if "requires Xcode" in stderr:
                issues.append({
                    "level": "error",
                    "message": "xcodebuild requires Xcode but only Command Line Tools installed",
                    "fix": "Install full Xcode from Mac App Store"
                })
                installation = {
                    "method": "Install Xcode",
                    "url": "https://apps.apple.com/us/app/xcode/id497799835"
                }
            else:
                issues.append({
                    "level": "error",
                    "message": f"xcodebuild not working: {stderr}",
                    "fix": "Check Xcode installation"
                })

            return ToolResult(
                id="xcodebuild",
                name="xcodebuild",
                category="required",
                status="error",
                installed=shutil.which("xcodebuild") is not None,
                working=False,
                check_type="command",
                issues=issues,
                installation=installation
            )

    def check_framework(self, framework_name: str, paths: List[str]) -> ToolResult:
        """Check for macOS framework availability."""
        for path in paths:
            if Path(path).exists():
                return ToolResult(
                    id=framework_name.lower().replace(" ", "_"),
                    name=framework_name,
                    category="project-specific",
                    status="found",
                    installed=True,
                    working=True,
                    path=path,
                    check_type="framework"
                )

        return ToolResult(
            id=framework_name.lower().replace(" ", "_"),
            name=framework_name,
            category="project-specific",
            status="not_found",
            installed=False,
            working=False,
            check_type="framework",
            issues=[{
                "level": "warning",
                "message": f"{framework_name} not found",
                "fix": "May require Xcode or macOS SDK installation"
            }]
        )

    def check_tool(self, tool_config: Dict) -> ToolResult:
        """Check a tool based on its configuration."""
        check_type = tool_config.get("check", {}).get("type", "command")

        if check_type == "custom":
            # Handle custom checks
            function_name = tool_config["check"]["function"]
            if function_name == "check_xcode":
                return self.check_xcode()
            elif function_name == "check_xcode_clt":
                return self.check_xcode_clt()
            elif function_name == "check_xcodebuild":
                return self.check_xcodebuild()
            # Add more custom functions as needed

        elif check_type == "command":
            command = tool_config["check"]["command"]
            version_flag = tool_config["check"].get("version_flag", "--version")
            version_regex = tool_config["check"].get("version_regex")

            exists, version, path = self.check_command(command, version_flag, version_regex)

            installation = None
            if not exists and "installation" in tool_config:
                inst = tool_config["installation"]
                if "primary" in inst:
                    installation = inst["primary"]

            return ToolResult(
                id=tool_config["id"],
                name=tool_config["name"],
                category=tool_config["category"],
                status="found" if exists else "not_found",
                installed=exists,
                working=exists,
                version=version,
                path=path,
                check_type="command",
                issues=[] if exists else [{
                    "level": "error" if tool_config["category"] == "required" else "warning",
                    "message": f"{tool_config['name']} not found",
                    "fix": installation.get("command") if installation else None
                }],
                installation=installation
            )

        elif check_type == "directory":
            paths = tool_config["check"]["paths"]
            for path in paths:
                if Path(path).exists():
                    return ToolResult(
                        id=tool_config["id"],
                        name=tool_config["name"],
                        category=tool_config["category"],
                        status="found",
                        installed=True,
                        working=True,
                        path=path,
                        check_type="directory"
                    )

            return ToolResult(
                id=tool_config["id"],
                name=tool_config["name"],
                category=tool_config["category"],
                status="not_found",
                installed=False,
                working=False,
                check_type="directory"
            )

        elif check_type == "framework":
            return self.check_framework(
                tool_config["name"],
                tool_config["check"]["paths"]
            )

        return ToolResult(
            id=tool_config["id"],
            name=tool_config["name"],
            category=tool_config["category"],
            status="error",
            installed=False,
            working=False,
            check_type=check_type,
            issues=[{
                "level": "error",
                "message": f"Unknown check type: {check_type}"
            }]
        )

    def get_system_info(self) -> Dict:
        """Gather system information."""
        return {
            "os": platform.system(),
            "os_version": platform.mac_ver()[0] if platform.system() == "Darwin" else platform.version(),
            "architecture": platform.machine(),
            "hostname": platform.node()
        }

    def run_checks(self) -> Dict:
        """Run all configured checks and return results."""
        results = []

        # Check tools from configuration
        for tool in self.config.get("tools", []):
            result = self.check_tool(tool)
            results.append(asdict(result))

        # Calculate summary
        required_tools = [r for r in results if r["category"] == "required"]
        optional_tools = [r for r in results if r["category"] == "optional"]

        all_required_present = all(r["working"] for r in required_tools)

        return {
            "timestamp": datetime.now().isoformat(),
            "summary": {
                "all_required_present": all_required_present,
                "required_count": len(required_tools),
                "required_present": sum(1 for r in required_tools if r["working"]),
                "optional_count": len(optional_tools),
                "optional_present": sum(1 for r in optional_tools if r["working"])
            },
            "system": self.system_info,
            "tools": results,
            "recommendations": self.generate_recommendations(results)
        }

    def generate_recommendations(self, results: List[Dict]) -> List[Dict]:
        """Generate recommendations based on check results."""
        recommendations = []

        # Check for critical missing tools
        for tool in results:
            if tool["category"] == "required" and not tool["working"]:
                priority = "critical"
                message = f"Install {tool['name']} - required for building"
                action = None

                if tool.get("installation"):
                    action = tool["installation"].get("command") or tool["installation"].get("url")

                recommendations.append({
                    "priority": priority,
                    "message": message,
                    "action": action
                })

        # Check for recommended optional tools
        for tool in results:
            if tool["category"] == "optional" and not tool["working"]:
                recommendations.append({
                    "priority": "low",
                    "message": f"Consider installing {tool['name']}",
                    "action": tool.get("installation", {}).get("command") if tool.get("installation") else None
                })

        return recommendations


class TextFormatter:
    """Format results as colored text output."""

    # ANSI color codes
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

    def format(self, results: Dict) -> str:
        """Format results as colored text."""
        lines = []

        lines.append("🔍 Development Tools Check for Radial Menu")
        lines.append("===========================================")
        lines.append("")

        # Group tools by category
        required = [t for t in results["tools"] if t["category"] == "required"]
        optional = [t for t in results["tools"] if t["category"] == "optional"]
        project = [t for t in results["tools"] if t["category"] == "project-specific"]

        if required:
            lines.append(f"{self.BLUE}Required Tools:{self.NC}")
            lines.append("---------------")
            for tool in required:
                lines.extend(self.format_tool(tool))

        if optional:
            lines.append(f"{self.BLUE}Optional Tools:{self.NC}")
            lines.append("---------------")
            for tool in optional:
                lines.extend(self.format_tool(tool))

        if project:
            lines.append(f"{self.BLUE}Project-Specific Checks:{self.NC}")
            lines.append("------------------------")
            for tool in project:
                lines.extend(self.format_tool(tool))

        # System info
        lines.append(f"{self.BLUE}System Info:{self.NC}")
        lines.append("------------")
        lines.append(f"OS: {results['system']['os']} {results['system']['os_version']}")
        lines.append(f"Architecture: {results['system']['architecture']}")
        lines.append("")

        # Summary
        lines.append("===========================================")
        lines.append("")

        if results["summary"]["all_required_present"]:
            lines.append(f"{self.GREEN}✅ All required tools are installed!{self.NC}")
            lines.append("")
            lines.append("You can now build the project with:")
            lines.append("  just build")
        else:
            lines.append(f"{self.RED}❌ Some required tools are missing.{self.NC}")
            lines.append("")
            lines.append("Please install the missing required tools before proceeding.")

            # Show quick fixes
            critical_recs = [r for r in results["recommendations"] if r["priority"] == "critical"]
            if critical_recs:
                lines.append("")
                lines.append("Quick fixes:")
                for rec in critical_recs:
                    lines.append(f"  • {rec['message']}")
                    if rec.get("action"):
                        lines.append(f"    {rec['action']}")

        lines.append("")
        return "\n".join(lines)

    def format_tool(self, tool: Dict) -> List[str]:
        """Format a single tool result."""
        lines = []

        # Status icon and name
        if tool["status"] == "found":
            status_icon = f"{self.GREEN}✓{self.NC}"
        elif tool["status"] == "not_found":
            if tool["category"] == "required":
                status_icon = f"{self.RED}✗{self.NC}"
            else:
                status_icon = f"{self.YELLOW}⚠{self.NC}"
        else:
            status_icon = f"{self.YELLOW}⚠{self.NC}"

        status_text = "Found" if tool["working"] else "Not found"
        if tool["category"] != "required" and not tool["working"]:
            status_text += " (optional)"

        lines.append(f"Checking {tool['name']}... {status_icon} {status_text}")

        # Version and path
        if tool.get("version"):
            lines.append(f"  └─ Version: {tool['version']}")
        if tool.get("path"):
            lines.append(f"  └─ Path: {tool['path']}")

        # Issues
        for issue in tool.get("issues", []):
            lines.append(f"  └─ {issue['message']}")
            if issue.get("fix"):
                lines.append(f"      Fix: {issue['fix']}")

        # Installation
        if not tool["working"] and tool.get("installation"):
            inst = tool["installation"]
            if inst.get("command"):
                lines.append(f"  └─ Install: {inst['command']}")
            elif inst.get("url"):
                lines.append(f"  └─ Install: {inst['url']}")

        lines.append("")
        return lines


def main():
    parser = argparse.ArgumentParser(description="Check development tools for Radial Menu project")
    parser.add_argument("-o", "--output", choices=["json", "text", "both"],
                       default="text", help="Output format")
    parser.add_argument("-c", "--config", type=Path,
                       help="Path to tools configuration file")
    parser.add_argument("-f", "--file", type=Path,
                       help="Write output to file")
    parser.add_argument("-v", "--verbose", action="store_true",
                       help="Verbose output")
    parser.add_argument("--pretty", action="store_true",
                       help="Pretty print JSON output")
    parser.add_argument("--exit-on-missing", action="store_true",
                       help="Exit with error if required tools are missing")

    args = parser.parse_args()

    checker = DevToolsChecker(config_path=args.config)
    results = checker.run_checks()

    # Generate output
    output = ""
    if args.output in ["json", "both"]:
        if args.pretty:
            output = json.dumps(results, indent=2, sort_keys=True)
        else:
            output = json.dumps(results)

        if args.output == "json":
            print(output)

    if args.output in ["text", "both"]:
        formatter = TextFormatter()
        text_output = formatter.format(results)

        if args.output == "both":
            print("\n" + "="*50 + "\n")

        print(text_output)

    # Write to file if specified
    if args.file:
        with open(args.file, 'w') as f:
            f.write(output if args.output == "json" else text_output)

    # Exit code based on results
    if args.exit_on_missing and not results["summary"]["all_required_present"]:
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()