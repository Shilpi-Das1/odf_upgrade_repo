#!/usr/bin/env python3
"""
Bastion Artifact Fetcher and JIRA Integration Script

This script fetches artifacts from a bastion machine via SSH/SCP, parses test-summary.txt,
updates subtask_config.json, creates JIRA subtasks, adds comments with test results,
and uploads test-summary.txt and odf_tier_logs-*.tar.gz as JIRA attachments.

Usage:
    python fetch_bastion_artifacts.py --ip 192.168.1.100 [--due-date "17/Jun/26"]
    python fetch_bastion_artifacts.py --ip 192.168.1.100 --key-file /path/to/id_rsa
"""

import os
import sys
import json
import re
import argparse
import shutil
import subprocess
from pathlib import Path
from datetime import datetime
from dotenv import load_dotenv
import urllib3
from jira_utils import JiraHelper

# Disable SSL warnings for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class BastionArtifactFetcher:
    """Class to handle bastion artifact fetching and JIRA integration"""
    
    def __init__(self, bastion_ip, ssh_key_file=None, ssh_user='root'):
        """Initialize with bastion connection details"""
        load_dotenv()
        
        # Bastion connection details
        self.bastion_ip = bastion_ip
        self.ssh_user = ssh_user
        self.ssh_key_file = ssh_key_file or 'id_rsa'
        
        # Validate SSH key file exists
        if not Path(self.ssh_key_file).exists():
            raise FileNotFoundError(
                f"SSH key file not found: {self.ssh_key_file}\n"
                f"Please ensure the private key file exists in the current directory or provide --key-file path"
            )
        
        # Initialize JIRA helper
        self.jira_helper = JiraHelper()
        self.jira_server = self.jira_helper.jira_server
        
        # Create artifacts directory
        self.artifacts_dir = Path("bastion_artifacts")
        self.artifacts_dir.mkdir(exist_ok=True)
        
        print(f"✓ Bastion connection configured: {self.ssh_user}@{self.bastion_ip}")
        print(f"✓ Using SSH key: {self.ssh_key_file}")
    
    def fetch_artifacts_from_bastion(self, remote_dir='/root', skip_if_exists=False):
        """Fetch artifacts from bastion machine via SCP"""
        print(f"\n{'='*60}")
        print(f"Fetching artifacts from bastion machine")
        print(f"{'='*60}")
        
        # Check if artifacts already exist locally
        if skip_if_exists and self.artifacts_dir.exists():
            existing_files = list(self.artifacts_dir.glob('*'))
            if existing_files:
                print(f"✓ Found {len(existing_files)} existing artifact(s) in {self.artifacts_dir}")
                print(f"  Skipping download (using cached artifacts)")
                return existing_files
        
        # Define artifact patterns to fetch
        artifact_patterns = [
            'test-summary*.txt',
            'must-gather*.tar.gz',
            'odf_tier_logs*.tar.gz'
        ]
        
        downloaded_files = []
        
        for pattern in artifact_patterns:
            print(f"\n  Fetching: {pattern}")
            
            # Construct SCP command
            # Use -i for key file, -o StrictHostKeyChecking=no to avoid host key prompt
            remote_path = f"{self.ssh_user}@{self.bastion_ip}:{remote_dir}/{pattern}"
            
            scp_command = [
                'scp',
                '-i', self.ssh_key_file,
                '-o', 'StrictHostKeyChecking=no',
                '-o', 'UserKnownHostsFile=/dev/null',
                remote_path,
                str(self.artifacts_dir)
            ]
            
            try:
                # Run SCP command
                result = subprocess.run(
                    scp_command,
                    capture_output=True,
                    text=True,
                    encoding='utf-8',
                    errors='replace'
                )
                
                if result.returncode == 0:
                    # Find downloaded files matching pattern
                    found_files = list(self.artifacts_dir.glob(pattern))
                    if found_files:
                        for file in found_files:
                            print(f"  ✓ Downloaded: {file.name}")
                            downloaded_files.append(file)
                    else:
                        print(f"  ⚠ No files matching pattern: {pattern}")
                else:
                    # Check if it's just "no matching files" error
                    if 'No such file or directory' in result.stderr or not result.stderr.strip():
                        print(f"  ⚠ No files found matching: {pattern}")
                    else:
                        print(f"  ✗ Error fetching {pattern}: {result.stderr}")
                        
            except Exception as e:
                print(f"  ✗ Error fetching {pattern}: {str(e)}")
        
        if not downloaded_files:
            raise Exception("No artifacts downloaded from bastion machine")
        
        print(f"\n✓ Downloaded {len(downloaded_files)} artifact(s) from bastion")
        return downloaded_files
    
    
    def cleanup_artifacts(self):
        """Delete downloaded artifacts"""
        print(f"\n{'='*60}")
        print(f"Cleaning up artifacts")
        print(f"{'='*60}")
        
        if self.artifacts_dir.exists():
            shutil.rmtree(self.artifacts_dir)
            print(f"✓ Deleted {self.artifacts_dir}")
        else:
            print(f"⚠ Artifacts directory not found")
    
    def process(self, remote_dir='/root', due_date=None, resume=False):
        """Main processing workflow"""
        subtask_key = None
        all_steps_successful = False
        
        try:
            # Step 1: Fetch artifacts from bastion
            downloaded_files = self.fetch_artifacts_from_bastion(remote_dir, skip_if_exists=resume)
            
            if not downloaded_files:
                raise Exception("No artifacts downloaded")
            
            # Step 2: Find test-summary*.txt and odf_tier_logs tar.gz
            test_summary_path = None
            tier_logs_tar_path = None
            
            for file_path in downloaded_files:
                if file_path.name.startswith('test-summary') and file_path.name.endswith('.txt'):
                    test_summary_path = file_path
                elif file_path.name.startswith('odf_tier_logs') and file_path.name.endswith('.tar.gz'):
                    tier_logs_tar_path = file_path
            
            if not test_summary_path:
                raise FileNotFoundError("test-summary*.txt not found in artifacts")
            
            # Step 3: Parse test-summary.txt using JiraHelper
            parsed_data = self.jira_helper.parse_test_summary(test_summary_path)
            
            # Step 4: Update subtask_config.json using JiraHelper
            self.jira_helper.update_subtask_config(
                parsed_data['odf_version'],
                parsed_data['odf_summary'],
                due_date
            )
            
            # Step 5: Create JIRA subtask using JiraHelper
            subtask_key = self.jira_helper.create_jira_subtask()
            
            # Step 6: Add comments to JIRA using JiraHelper
            self.jira_helper.add_comments_to_jira(subtask_key, parsed_data['sections'], skip_if_exists=resume)
            
            # Step 7: Upload test-summary.txt as attachment using JiraHelper
            self.jira_helper.upload_attachment_to_jira(subtask_key, test_summary_path, skip_if_exists=resume)
            
            # Step 8: Upload odf_tier_logs tar.gz if found using JiraHelper
            if tier_logs_tar_path:
                self.jira_helper.upload_attachment_to_jira(subtask_key, tier_logs_tar_path, skip_if_exists=resume)
            else:
                print(f"⚠ Warning: odf_tier_logs*.tar.gz not found in artifacts")
            
            # Mark all steps as successful
            all_steps_successful = True
            
            # Step 9: Cleanup artifacts only if all steps succeeded
            self.cleanup_artifacts()
            
            print(f"\n{'='*60}")
            print(f"✓ Process completed successfully!")
            print(f"{'='*60}")
            print(f"JIRA Subtask: {subtask_key}")
            jira_url = self.jira_server.rstrip('/') if self.jira_server else ''
            print(f"URL: {jira_url}/browse/{subtask_key}")
            print(f"{'='*60}")
            
            return subtask_key
            
        except Exception as e:
            print(f"\n✗ Error: {str(e)}", file=sys.stderr)
            if not all_steps_successful:
                print(f"\n⚠ Artifacts preserved in '{self.artifacts_dir}' for retry")
                print(f"  Fix the issue and re-run with --resume flag to skip completed steps")
            raise


def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description='Fetch artifacts from bastion machine and create JIRA subtask with test results',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python fetch_bastion_artifacts.py --ip 192.168.1.100
    python fetch_bastion_artifacts.py --ip 192.168.1.100 --due-date "17/Jun/26"
    python fetch_bastion_artifacts.py --ip 192.168.1.100 --remote-dir /home/user --resume
    python fetch_bastion_artifacts.py --ip 192.168.1.100 --key-file ~/.ssh/my_key

Environment Variables Required (.env file):
    JIRA_SERVER - JIRA server URL
    JIRA_EMAIL - JIRA email
    JIRA_API_TOKEN - JIRA API token

SSH Key:
    Place your private key file (id_rsa) in the current directory,
    or specify a custom path with --key-file
        """
    )
    
    parser.add_argument(
        '--ip',
        required=True,
        help='Bastion machine IP address'
    )
    
    parser.add_argument(
        '--remote-dir',
        default='/root',
        help='Remote directory containing artifacts (default: /root)'
    )
    
    parser.add_argument(
        '--key-file',
        default='id_rsa',
        help='Path to SSH private key file (default: id_rsa in current directory)'
    )
    
    parser.add_argument(
        '--user',
        default='root',
        help='SSH username (default: root)'
    )
    
    parser.add_argument(
        '-d', '--due-date',
        required=False,
        default=None,
        help='Due date for JIRA subtask (format: d/MMM/yy, e.g., 17/Jun/26). Optional.'
    )
    
    parser.add_argument(
        '-r', '--resume',
        action='store_true',
        help='Resume from previous run, skip already completed steps'
    )
    
    args = parser.parse_args()
    
    # Handle empty string as None
    due_date = args.due_date if args.due_date and args.due_date.strip() else None
    
    try:
        fetcher = BastionArtifactFetcher(
            bastion_ip=args.ip,
            ssh_key_file=args.key_file,
            ssh_user=args.user
        )
        fetcher.process(
            remote_dir=args.remote_dir,
            due_date=due_date,
            resume=args.resume
        )
        return 0
        
    except Exception as e:
        print(f"\n✗ Fatal Error: {str(e)}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())

# Made with Bob