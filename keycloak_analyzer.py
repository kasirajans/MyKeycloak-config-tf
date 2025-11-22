#!/usr/bin/env python3
"""
Keycloak Terraform Resource Analyzer
=====================================

A comprehensive Python script to analyze Terraform resources for Keycloak configurations.
Provides detailed summaries, filtering, and export capabilities specific to Keycloak infrastructure.

Author: Terraform Resource Analyzer
Date: November 2025
"""

import json
import os
import sys
import subprocess
import argparse
from pathlib import Path
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
from datetime import datetime

try:
    import rich
    from rich.console import Console
    from rich.table import Table
    from rich.tree import Tree
    from rich.panel import Panel
    from rich.progress import Progress
    from rich.syntax import Syntax
    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False
    Console = None
    print("⚠️  Rich not available. Install with: pip install rich")

@dataclass
class TerraformWorkspace:
    """Represents a Terraform workspace with its configuration and state."""
    path: Path
    name: str
    has_state: bool
    resources: List[Dict[str, Any]]
    outputs: Dict[str, Any]

class KeycloakResourceAnalyzer:
    """Main class for analyzing Keycloak Terraform resources."""

    def __init__(self, base_path: str = ".", console: Any = None):
        self.base_path = Path(base_path).resolve()
        self.console = console or Console() if RICH_AVAILABLE else None
        self.workspaces = {}
        self.summary_data = {}

    def log(self, message: str, style: str = ""):
        if self.console and RICH_AVAILABLE:
            self.console.print(message, style=style)
        else:
            print(message)

    def find_terraform_workspaces(self) -> Dict[str, TerraformWorkspace]:
        workspaces = {}
        self.log(f"🔍 Scanning for Terraform workspaces in: {self.base_path}", "cyan")
        for root, dirs, files in os.walk(self.base_path):
            if 'main.tf' in files or any(f.endswith('.tf') for f in files):
                workspace_path = Path(root)
                workspace_name = str(workspace_path.relative_to(self.base_path))
                has_state = (workspace_path / 'terraform.tfstate').exists()
                workspace = TerraformWorkspace(
                    path=workspace_path,
                    name=workspace_name if workspace_name != '.' else 'root',
                    has_state=has_state,
                    resources=[],
                    outputs={}
                )
                workspaces[workspace_name] = workspace
        self.log(f"✅ Found {len(workspaces)} Terraform workspaces", "green")
        return workspaces

    def load_terraform_state(self, workspace: TerraformWorkspace) -> bool:
        if not workspace.has_state:
            return False
        try:
            os.chdir(workspace.path)
            result = subprocess.run(
                ['terraform', 'show', '-json'],
                capture_output=True,
                text=True,
                check=True
            )
            state_data = json.loads(result.stdout)
            if 'values' in state_data and 'root_module' in state_data['values']:
                workspace.resources = state_data['values']['root_module'].get('resources', [])
            try:
                output_result = subprocess.run(
                    ['terraform', 'output', '-json'],
                    capture_output=True,
                    text=True,
                    check=True
                )
                workspace.outputs = json.loads(output_result.stdout)
            except (subprocess.CalledProcessError, json.JSONDecodeError):
                workspace.outputs = {}
            return True
        except (subprocess.CalledProcessError, json.JSONDecodeError, FileNotFoundError) as e:
            self.log(f"❌ Failed to load state for {workspace.name}: {e}", "red")
            return False
        finally:
            os.chdir(self.base_path)

    def categorize_keycloak_resources(self, resources: List[Dict]) -> Dict[str, List[Dict]]:
        categories = {
            'realms': [],
            'users': [],
            'clients': [],
            'roles': [],
            'groups': [],
            'identity_providers': [],
            'authentication_flows': [],
            'scopes': [],
            'mappers': [],
            'other': []
        }
        for resource in resources:
            resource_type = resource.get('type', '')
            if 'realm' in resource_type and resource_type != 'keycloak_user':
                categories['realms'].append(resource)
            elif 'user' in resource_type:
                categories['users'].append(resource)
            elif 'client' in resource_type:
                categories['clients'].append(resource)
            elif 'role' in resource_type:
                categories['roles'].append(resource)
            elif 'group' in resource_type:
                categories['groups'].append(resource)
            elif 'identity_provider' in resource_type or 'idp' in resource_type:
                categories['identity_providers'].append(resource)
            elif 'authentication' in resource_type or 'flow' in resource_type:
                categories['authentication_flows'].append(resource)
            elif 'scope' in resource_type:
                categories['scopes'].append(resource)
            elif 'mapper' in resource_type:
                categories['mappers'].append(resource)
            else:
                categories['other'].append(resource)
        return categories

    def analyze_user_security(self, users: List[Dict]) -> Dict[str, Any]:
        security_analysis = {
            'total_users': len(users),
            'users_with_passwords': 0,
            'users_without_passwords': 0,
            'temporary_passwords': 0,
            'enabled_users': 0,
            'disabled_users': 0,
            'users_requiring_password_change': 0,
            'user_details': []
        }
        for user in users:
            values = user.get('values', {})
            user_info = {
                'username': values.get('username', 'unknown'),
                'email': values.get('email', ''),
                'enabled': values.get('enabled', True),
                'has_password': False,
                'temporary_password': False,
                'requires_password_change': False
            }
            if 'initial_password' in values:
                user_info['has_password'] = True
                security_analysis['users_with_passwords'] += 1
                if values.get('initial_password', {}).get('temporary', False):
                    user_info['temporary_password'] = True
                    security_analysis['temporary_passwords'] += 1
            else:
                security_analysis['users_without_passwords'] += 1
            if values.get('enabled', True):
                security_analysis['enabled_users'] += 1
                user_info['enabled'] = True
            else:
                security_analysis['disabled_users'] += 1
                user_info['enabled'] = False
            security_analysis['user_details'].append(user_info)
        return security_analysis

    def generate_workspace_summary(self, workspace: TerraformWorkspace) -> Dict[str, Any]:
        if not workspace.resources:
            return {
                'name': workspace.name,
                'path': str(workspace.path),
                'has_state': workspace.has_state,
                'resource_count': 0,
                'categories': {},
                'error': 'No resources found or state not loaded'
            }
        categories = self.categorize_keycloak_resources(workspace.resources)
        summary = {
            'name': workspace.name,
            'path': str(workspace.path),
            'has_state': workspace.has_state,
            'resource_count': len(workspace.resources),
            'categories': {k: len(v) for k, v in categories.items() if v},
            'detailed_analysis': {}
        }
        if categories['users']:
            summary['detailed_analysis']['user_security'] = self.analyze_user_security(categories['users'])
        if categories['realms']:
            summary['detailed_analysis']['realms'] = [
                {
                    'name': r.get('values', {}).get('realm', 'unknown'),
                    'enabled': r.get('values', {}).get('enabled', True),
                    'display_name': r.get('values', {}).get('display_name', ''),
                    'address': r.get('address', '')
                }
                for r in categories['realms']
            ]
        if categories['clients']:
            summary['detailed_analysis']['clients'] = [
                {
                    'client_id': c.get('values', {}).get('client_id', 'unknown'),
                    'name': c.get('values', {}).get('name', ''),
                    'enabled': c.get('values', {}).get('enabled', True),
                    'protocol': c.get('values', {}).get('protocol', ''),
                    'address': c.get('address', '')
                }
                for c in categories['clients']
            ]
        if categories['identity_providers']:
            summary['detailed_analysis']['identity_providers'] = [
                {
                    'alias': idp.get('values', {}).get('alias', 'unknown'),
                    'provider_id': idp.get('values', {}).get('provider_id', ''),
                    'enabled': idp.get('values', {}).get('enabled', True),
                    'address': idp.get('address', '')
                }
                for idp in categories['identity_providers']
            ]
        summary['outputs'] = workspace.outputs
        return summary

    def display_high_level_summary(self):
        if not RICH_AVAILABLE:
            self._display_simple_summary()
            return
        table = Table(title="🔐 Keycloak Terraform Infrastructure Overview")
        table.add_column("Workspace", style="cyan")
        table.add_column("Resources", justify="right", style="green")
        table.add_column("Realms", justify="right", style="blue")
        table.add_column("Users", justify="right", style="yellow")
        table.add_column("Clients", justify="right", style="magenta")
        table.add_column("IDPs", justify="right", style="red")
        table.add_column("State", style="green")
        total_resources = 0
        total_realms = 0
        total_users = 0
        total_clients = 0
        total_idps = 0
        for workspace_name, summary in self.summary_data.items():
            categories = summary.get('categories', {})
            realms = categories.get('realms', 0)
            users = categories.get('users', 0)
            clients = categories.get('clients', 0)
            idps = categories.get('identity_providers', 0)
            resource_count = summary.get('resource_count', 0)
            total_resources += resource_count
            total_realms += realms
            total_users += users
            total_clients += clients
            total_idps += idps
            state_status = "✅ Has State" if summary.get('has_state') else "❌ No State"
            table.add_row(
                workspace_name,
                str(resource_count),
                str(realms),
                str(users),
                str(clients),
                str(idps),
                state_status
            )
        table.add_section()
        table.add_row(
            "TOTAL",
            str(total_resources),
            str(total_realms),
            str(total_users),
            str(total_clients),
            str(total_idps),
            "",
            style="bold"
        )
        self.console.print(table)
        stats_panel = Panel(
            f"📊 Total Workspaces: {len(self.summary_data)}\n"
            f"📦 Total Resources: {total_resources}\n"
            f"🏰 Total Realms: {total_realms}\n"
            f"👥 Total Users: {total_users}\n"
            f"📱 Total Clients: {total_clients}\n"
            f"🔗 Total Identity Providers: {total_idps}",
            title="Summary Statistics",
            expand=False
        )
        self.console.print(stats_panel)

    def _display_simple_summary(self):
        print("\n" + "="*60)
        print("🔐 KEYCLOAK TERRAFORM INFRASTRUCTURE OVERVIEW")
        print("="*60)
        total_resources = 0
        for workspace_name, summary in self.summary_data.items():
            categories = summary.get('categories', {})
            resource_count = summary.get('resource_count', 0)
            total_resources += resource_count
            print(f"\n📁 Workspace: {workspace_name}")
            print(f"   Resources: {resource_count}")
            print(f"   Realms: {categories.get('realms', 0)}")
            print(f"   Users: {categories.get('users', 0)}")
            print(f"   Clients: {categories.get('clients', 0)}")
            print(f"   Identity Providers: {categories.get('identity_providers', 0)}")
            print(f"   State: {'✅ Present' if summary.get('has_state') else '❌ Missing'}")
        print(f"\n📊 TOTALS: {len(self.summary_data)} workspaces, {total_resources} resources")

    def display_detailed_analysis(self, filter_type: str = "all"):
        if filter_type == "users":
            self._display_user_analysis()
        elif filter_type == "realms":
            self._display_realm_analysis()
        elif filter_type == "clients":
            self._display_client_analysis()
        elif filter_type == "idp":
            self._display_idp_analysis()
        elif filter_type == "auth":
            self._display_auth_analysis()
        else:
            self._display_complete_analysis()

    def _display_user_analysis(self):
        if not RICH_AVAILABLE:
            print("\n" + "="*50)
            print("👥 USER SECURITY ANALYSIS")
            print("="*50)
        else:
            self.console.print("\n[bold blue]👥 USER SECURITY ANALYSIS[/bold blue]")
        for workspace_name, summary in self.summary_data.items():
            user_analysis = summary.get('detailed_analysis', {}).get('user_security')
            if not user_analysis:
                continue
            if RICH_AVAILABLE:
                table = Table(title=f"Users in {workspace_name}")
                table.add_column("Username", style="cyan")
                table.add_column("Email", style="blue")
                table.add_column("Enabled", style="green")
                table.add_column("Has Password", style="yellow")
                table.add_column("Temporary", style="red")
                for user in user_analysis['user_details']:
                    table.add_row(
                        user['username'],
                        user['email'] or 'N/A',
                        "✅" if user['enabled'] else "❌",
                        "✅" if user['has_password'] else "❌",
                        "⚠️" if user['temporary_password'] else "✅"
                    )
                self.console.print(table)
                security_panel = Panel(
                    f"Total Users: {user_analysis['total_users']}\n"
                    f"With Passwords: {user_analysis['users_with_passwords']}\n"
                    f"Without Passwords: {user_analysis['users_without_passwords']}\n"
                    f"Temporary Passwords: {user_analysis['temporary_passwords']}\n"
                    f"Enabled: {user_analysis['enabled_users']}\n"
                    f"Disabled: {user_analysis['disabled_users']}",
                    title=f"Security Summary - {workspace_name}",
                    expand=False
                )
                self.console.print(security_panel)
            else:
                print(f"\n📁 {workspace_name}:")
                print(f"   Total Users: {user_analysis['total_users']}")
                print(f"   With Passwords: {user_analysis['users_with_passwords']}")
                print(f"   Without Passwords: {user_analysis['users_without_passwords']}")
                print(f"   Temporary Passwords: {user_analysis['temporary_passwords']}")

    def _display_realm_analysis(self):
        title = "🏰 REALM CONFIGURATION ANALYSIS"
        if RICH_AVAILABLE:
            self.console.print(f"\n[bold blue]{title}[/bold blue]")
        else:
            print(f"\n{title}")
            print("="*len(title))
        for workspace_name, summary in self.summary_data.items():
            realms = summary.get('detailed_analysis', {}).get('realms', [])
            if not realms:
                continue
            if RICH_AVAILABLE:
                table = Table(title=f"Realms in {workspace_name}")
                table.add_column("Realm Name", style="cyan")
                table.add_column("Display Name", style="blue")
                table.add_column("Enabled", style="green")
                table.add_column("Resource Address", style="yellow")
                for realm in realms:
                    table.add_row(
                        realm['name'],
                        realm['display_name'] or 'N/A',
                        "✅" if realm['enabled'] else "❌",
                        realm['address']
                    )
                self.console.print(table)
            else:
                print(f"\n📁 {workspace_name}:")
                for realm in realms:
                    print(f"   🏰 {realm['name']} ({realm['display_name']})")
                    print(f"      Enabled: {'✅' if realm['enabled'] else '❌'}")

    def _display_complete_analysis(self):
        self.log("\n📋 COMPLETE RESOURCE ANALYSIS", "bold cyan")
        for workspace_name, summary in self.summary_data.items():
            if summary.get('resource_count', 0) == 0:
                continue
            self.log(f"\n📁 Workspace: {workspace_name}", "bold yellow")
            self.log(f"   Path: {summary['path']}", "dim")
            self.log(f"   Resources: {summary['resource_count']}", "green")
            categories = summary.get('categories', {})
            for category, count in categories.items():
                if count > 0:
                    self.log(f"   {category.replace('_', ' ').title()}: {count}", "blue")
            outputs = summary.get('outputs', {})
            if outputs:
                self.log("   Outputs:", "magenta")
                for output_name in outputs.keys():
                    self.log(f"     - {output_name}", "dim")

    def export_to_json(self, output_file: str):
        export_data = {
            'timestamp': datetime.now().isoformat(),
            'base_path': str(self.base_path),
            'analysis_summary': {
                'total_workspaces': len(self.summary_data),
                'total_resources': sum(s.get('resource_count', 0) for s in self.summary_data.values()),
                'workspaces_with_state': sum(1 for s in self.summary_data.values() if s.get('has_state')),
            },
            'workspaces': self.summary_data
        }
        with open(output_file, 'w') as f:
            json.dump(export_data, f, indent=2, default=str)
        self.log(f"✅ Analysis exported to: {output_file}", "green")

    def run_analysis(self):
        self.log("🚀 Starting Keycloak Terraform Analysis", "bold green")
        self.workspaces = self.find_terraform_workspaces()
        if not self.workspaces:
            self.log("❌ No Terraform workspaces found!", "red")
            return False
        loaded_count = 0
        if RICH_AVAILABLE:
            with Progress() as progress:
                task = progress.add_task("Loading Terraform states...", total=len(self.workspaces))
                for workspace in self.workspaces.values():
                    if self.load_terraform_state(workspace):
                        loaded_count += 1
                    progress.update(task, advance=1)
        else:
            for i, workspace in enumerate(self.workspaces.values(), 1):
                print(f"Loading {i}/{len(self.workspaces)}: {workspace.name}")
                if self.load_terraform_state(workspace):
                    loaded_count += 1
        self.log(f"✅ Loaded state from {loaded_count}/{len(self.workspaces)} workspaces", "green")
        for workspace in self.workspaces.values():
            self.summary_data[workspace.name] = self.generate_workspace_summary(workspace)
        return True

def main():
    parser = argparse.ArgumentParser(
        description="Analyze Keycloak Terraform infrastructure",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python keycloak_analyzer.py                    # Show high-level summary
  python keycloak_analyzer.py --filter users    # Show user analysis
  python keycloak_analyzer.py --filter realms   # Show realm analysis
  python keycloak_analyzer.py --detailed        # Show complete analysis
  python keycloak_analyzer.py --export report.json  # Export to JSON
        """
    )
    parser.add_argument('--path', '-p', default='.', 
                       help='Base path to scan for Terraform workspaces')
    parser.add_argument('--filter', '-f', 
                       choices=['users', 'realms', 'clients', 'idp', 'auth', 'all'],
                       help='Filter analysis by resource type')
    parser.add_argument('--detailed', '-d', action='store_true',
                       help='Show detailed analysis for all resources')
    parser.add_argument('--export', '-e', metavar='FILE',
                       help='Export analysis to JSON file')
    parser.add_argument('--no-color', action='store_true',
                       help='Disable colored output')
    args = parser.parse_args()
    console = None
    if RICH_AVAILABLE and not args.no_color:
        console = Console()
    analyzer = KeycloakResourceAnalyzer(args.path, console)
    if not analyzer.run_analysis():
        sys.exit(1)
    if args.detailed:
        analyzer.display_detailed_analysis('all')
    elif args.filter:
        analyzer.display_detailed_analysis(args.filter)
    else:
        analyzer.display_high_level_summary()
    if args.export:
        analyzer.export_to_json(args.export)
    print(f"\n🎉 Analysis complete! Analyzed {len(analyzer.workspaces)} workspaces.")

if __name__ == "__main__":
    main()