#!/usr/bin/env python3
"""
Jira Subtask Creation Script

This script creates Jira subtasks with automatic ODF version to parent key mapping.
Supports both ODF version-based and manual parent key specification.

Usage:
    # Using ODF version (recommended)
    python create_jira_subtask.py
    python create_jira_subtask.py --config my_config.json
    
    # List available ODF versions
    python create_jira_subtask.py --list-versions
"""

import os
import sys
import json
from datetime import datetime
from jira import JIRA
from dotenv import load_dotenv
import argparse


class JiraSubtaskCreator:
    """Class to handle Jira subtask creation"""
    
    def __init__(self, version_mapping_file='odf_version_mapping.json'):
        """Initialize Jira connection and load version mapping"""
        # Load environment variables from .env file
        load_dotenv()
        
        # Get Jira credentials from environment
        self.jira_server = os.getenv('JIRA_SERVER')
        self.jira_email = os.getenv('JIRA_EMAIL')
        self.jira_api_token = os.getenv('JIRA_API_TOKEN')
        self.project_key = os.getenv('JIRA_PROJECT_KEY')
        
        # Validate credentials
        if not all([self.jira_server, self.jira_email, self.jira_api_token]):
            raise ValueError(
                "Missing Jira credentials. Please set JIRA_SERVER, JIRA_EMAIL, "
                "and JIRA_API_TOKEN in .env file"
            )
        
        # Load ODF version to parent key mapping
        try:
            self.version_mapping = self.load_version_mapping(version_mapping_file)
        except FileNotFoundError:
            print(f"⚠ Warning: Version mapping file not found. ODF version feature disabled.")
            self.version_mapping = {}
        
        # Connect to Jira
        try:
            self.jira = JIRA(
                server=self.jira_server,
                basic_auth=(self.jira_email, self.jira_api_token)
            )
            print(f"✓ Connected to Jira: {self.jira_server}")
        except Exception as e:
            raise ConnectionError(f"Failed to connect to Jira: {str(e)}")
    
    def load_version_mapping(self, mapping_file):
        """Load ODF version to parent key mapping"""
        with open(mapping_file, 'r') as f:
            mapping = json.load(f)
        print(f"✓ Loaded ODF version mapping from: {mapping_file}")
        return mapping
    
    def get_parent_key_from_version(self, odf_version):
        """Get parent issue key from ODF version"""
        if not self.version_mapping:
            raise ValueError("ODF version mapping not loaded")
        
        if odf_version not in self.version_mapping:
            available_versions = ', '.join(sorted(self.version_mapping.keys()))
            raise ValueError(
                f"Unknown ODF version: {odf_version}\n"
                f"Available versions: {available_versions}"
            )
        
        parent_key = self.version_mapping[odf_version]
        print(f"✓ ODF Version {odf_version} → Parent Issue: {parent_key}")
        return parent_key
    
    def get_parent_issue(self, parent_key):
        """Get parent issue details"""
        try:
            parent = self.jira.issue(parent_key)
            print(f"✓ Found parent issue: {parent_key} - {parent.fields.summary}")
            return parent
        except Exception as e:
            raise ValueError(f"Parent issue '{parent_key}' not found: {str(e)}")
    
    def check_subtask_exists(self, parent_key, summary):
        """Check if a subtask with the same summary already exists under the parent"""
        try:
            # Search for subtasks of the parent issue
            jql = f'parent = {parent_key} AND issuetype = Sub-Task'
            issues = self.jira.search_issues(jql, maxResults=1000)
            
            # Check if any subtask has the same summary
            for issue in issues:
                if issue.fields.summary == summary:
                    print(f"⚠ Subtask with summary '{summary}' already exists: {issue.key}")
                    print(f"  URL: {self.jira_server.rstrip('/')}/browse/{issue.key}")
                    return issue
            
            return None
        except Exception as e:
            print(f"⚠ Warning: Could not check existing subtasks: {str(e)}")
            return None
    
    
    def parse_date(self, date_string):
        """
        Parse date string in format d/MMM/yy (e.g., 15/Jan/26)
        Returns date in YYYY-MM-DD format for Jira
        """
        if not date_string:
            return None
        
        try:
            date_obj = datetime.strptime(date_string, "%d/%b/%y")
            return date_obj.strftime("%Y-%m-%d")
        except ValueError:
            print(f"⚠ Warning: Invalid date format '{date_string}'. Expected: d/MMM/yy (e.g., 15/Jan/26)")
            return None
    
    def load_config(self, config_file):
        """Load configuration from JSON file"""
        try:
            with open(config_file, 'r') as f:
                config = json.load(f)
            print(f"✓ Loaded configuration from: {config_file}")
            return config
        except FileNotFoundError:
            raise FileNotFoundError(f"Configuration file not found: {config_file}")
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON in configuration file: {str(e)}")
    
    def validate_config(self, config):
        """Validate required fields in configuration"""
        # Check if using ODF version or manual parent key
        has_odf_version = 'odf_version' in config
        has_parent_key = 'parent_key' in config
        
        if not has_odf_version and not has_parent_key:
            raise ValueError("Config must have either 'odf_version' or 'parent_key'")
        
        required_fields = ['summary', 'description']
        missing_fields = [field for field in required_fields if field not in config]
        
        if missing_fields:
            raise ValueError(f"Missing required fields: {', '.join(missing_fields)}")
        
        return True
    
    def create_subtask_from_config(self, config):
        """
        Create a Jira subtask from configuration dictionary
        
        Args:
            config (dict): Configuration with subtask parameters
        
        Returns:
            JIRA Issue object: Created subtask
        """
        # Validate configuration
        self.validate_config(config)
        
        # Determine parent key (from ODF version or direct specification)
        if 'odf_version' in config:
            odf_version = config['odf_version']
            parent_key = self.get_parent_key_from_version(odf_version)
        else:
            parent_key = config['parent_key']
            print(f"✓ Using specified parent key: {parent_key}")
        
        # Extract parameters
        summary = config['summary']
        description = config['description']
        components = config.get('components', [])
        reporter = config.get('reporter')
        labels = config.get('labels', [])
        due_date = config.get('due_date')
        fix_versions = config.get('fix_versions', [])
        
        # Check if subtask with same summary already exists
        existing_subtask = self.check_subtask_exists(parent_key, summary)
        if existing_subtask:
            print(f"\n✓ Subtask already exists, skipping creation")
            return existing_subtask
        
        # Get parent issue
        parent = self.get_parent_issue(parent_key)
        
        # Get project from parent
        project = parent.fields.project.key
        
        # Build minimal required fields first
        # Using ID 10400 for Sub-Task issue type
        issue_fields = {
            'project': {'key': project},
            'summary': summary,
            'issuetype': {'id': '10400'},
            'parent': {'key': parent_key}
        }
        
        print(f"\nConfiguration:")
        if 'odf_version' in config:
            print(f"  ODF Version: {config['odf_version']}")
        print(f"  Parent: {parent_key}")
        print(f"  Project: {project}")
        print(f"  Summary: {summary}")
        
        # Try to add optional fields - they may not be available on all screens
        optional_fields = {}
        
        # Description
        if description:
            optional_fields['description'] = description
            print(f"  Description: {description[:50]}..." if len(description) > 50 else f"  Description: {description}")
        
        # Components
        if components:
            optional_fields['components'] = [{'name': comp} for comp in components]
            print(f"  Components: {', '.join(components)}")
        
        # Reporter
        if reporter:
            try:
                users = self.jira.search_users(reporter)
                if users:
                    optional_fields['reporter'] = {'accountId': users[0].accountId}
                    print(f"  Reporter: {reporter}")
                else:
                    print(f"⚠ Warning: Reporter '{reporter}' not found, using default")
            except Exception as e:
                print(f"⚠ Warning: Could not set reporter: {str(e)}")
        
        # Labels
        if labels:
            optional_fields['labels'] = labels
            print(f"  Labels: {', '.join(labels)}")
        
        # Due Date
        if due_date:
            parsed_date = self.parse_date(due_date)
            if parsed_date:
                optional_fields['duedate'] = parsed_date
                print(f"  Due Date: {due_date} ({parsed_date})")
        
        # Fix Versions
        if fix_versions:
            optional_fields['fixVersions'] = [{'name': ver} for ver in fix_versions]
            print(f"  Fix Versions: {', '.join(fix_versions)}")
        
        # Create the subtask with required fields first
        print(f"\nCreating subtask...")
        try:
            # Try with all fields first
            all_fields = {**issue_fields, **optional_fields}
            new_subtask = self.jira.create_issue(fields=all_fields)
            print(f"✓ Subtask created successfully: {new_subtask.key}")
            print(f"  URL: {self.jira_server.rstrip('/')}/browse/{new_subtask.key}")
            return new_subtask
        except Exception as e:
            error_msg = str(e)
            if "cannot be set" in error_msg.lower() or "not on the appropriate screen" in error_msg.lower():
                # Some fields are not allowed during creation, create first then update
                print(f"⚠ Some fields cannot be set during creation, will update after...")
                try:
                    # Create with minimal fields
                    new_subtask = self.jira.create_issue(fields=issue_fields)
                    print(f"✓ Subtask created: {new_subtask.key}")
                    
                    # Now try to update with optional fields
                    update_fields = {}
                    updated_fields = []
                    failed_fields = []
                    
                    for field_name, field_value in optional_fields.items():
                        try:
                            new_subtask.update(fields={field_name: field_value})
                            updated_fields.append(field_name)
                        except Exception as update_error:
                            failed_fields.append(field_name)
                            print(f"  ⚠ Could not set {field_name}: {str(update_error)}")
                    
                    if updated_fields:
                        print(f"✓ Updated fields: {', '.join(updated_fields)}")
                    
                    print(f"✓ Subtask created successfully: {new_subtask.key}")
                    print(f"  URL: {self.jira_server.rstrip('/')}/browse/{new_subtask.key}")
                    
                    if failed_fields:
                        print(f"\n⚠ Note: These fields could not be set and may need manual update:")
                        for field in failed_fields:
                            if field == 'description' and description:
                                print(f"  - Description: {description[:50]}...")
                            elif field == 'labels' and labels:
                                print(f"  - Labels: {', '.join(labels)}")
                            elif field == 'fixVersions' and fix_versions:
                                print(f"  - Fix Versions: {', '.join(fix_versions)}")
                    
                    return new_subtask
                except Exception as e2:
                    raise Exception(f"Failed to create subtask: {str(e2)}")
            else:
                raise Exception(f"Failed to create subtask: {error_msg}")
    
    def show_available_versions(self):
        """Display available ODF versions and their parent keys"""
        if not self.version_mapping:
            print("No ODF version mapping available")
            return
        
        print("\nAvailable ODF Versions:")
        print("="*60)
        for version in sorted(self.version_mapping.keys()):
            parent = self.version_mapping[version]
            print(f"  ODF {version} → {parent}")
        print("="*60)
    
    def show_issue_types(self):
        """Display all available issue types in Jira"""
        try:
            print("\nAvailable Issue Types in Jira:")
            print("="*60)
            issue_types = self.jira.issue_types()
            for issue_type in issue_types:
                subtask_indicator = " (SUBTASK)" if issue_type.subtask else ""
                print(f"  ID: {issue_type.id:5} | Name: {issue_type.name:30} {subtask_indicator}")
            print("="*60)
        except Exception as e:
            print(f"Error getting issue types: {str(e)}")


def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description='Create Jira subtask from JSON configuration',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Configuration File Format (JSON):

Method 1 - Using ODF Version (Recommended):
{
  "odf_version": "4.18",
  "summary": "Task title",
  "description": "Task description",
  "components": ["Backend", "API"],
  "labels": ["bug", "urgent"],
  "due_date": "15/Jan/26",
  "fix_versions": ["v4.18.0"]
}

Method 2 - Using Manual Parent Key:
{
  "parent_key": "CSOP-546",
  "summary": "Task title",
  "description": "Task description"
}

Required: (odf_version OR parent_key), summary, description
Optional: components, reporter, labels, due_date, fix_versions

Examples:
  python create_jira_subtask.py
  python create_jira_subtask.py --config my_config.json
  python create_jira_subtask.py --list-versions
        """
    )
    
    parser.add_argument(
        '--config',
        default='subtask_config.json',
        help='Path to JSON configuration file (default: subtask_config.json)'
    )
    
    parser.add_argument(
        '--list-versions',
        action='store_true',
        help='List available ODF versions and exit'
    )
    
    parser.add_argument(
        '--list-issue-types',
        action='store_true',
        help='List all available issue types in Jira and exit'
    )
    
    args = parser.parse_args()
    
    try:
        creator = JiraSubtaskCreator()
        
        if args.list_versions:
            creator.show_available_versions()
            return 0
        
        if args.list_issue_types:
            creator.show_issue_types()
            return 0
        
        print("\n" + "="*60)
        print("Creating Jira Subtask")
        print("="*60)
        
        config = creator.load_config(args.config)
        subtask = creator.create_subtask_from_config(config)
        
        print("="*60)
        print("✓ Success!")
        print("="*60)
        
        return 0
        
    except Exception as e:
        print(f"\n✗ Error: {str(e)}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())

# Made with Bob
