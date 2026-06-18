#!/usr/bin/env python3
"""
Jenkins Artifact Fetcher and JIRA Integration Script

This script fetches artifacts from Jenkins builds, parses test-summary.txt,
updates subtask_config.json, creates JIRA subtasks, adds comments with test results,
and uploads test-summary.txt and odf_tier_logs-*.tar.gz as attachments.

Usage:
    python fetch_jenkins_artifacts.py --build-number 123 [--due-date "17/Jun/26"]
    python fetch_jenkins_artifacts.py --build-number 123
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
import requests
from requests.auth import HTTPBasicAuth
from dotenv import load_dotenv
from jira import JIRA
import urllib3

# Disable SSL warnings for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class JenkinsArtifactFetcher:
    """Class to handle Jenkins artifact fetching and JIRA integration"""
    
    def __init__(self):
        """Initialize with environment variables"""
        load_dotenv()
        
        # Jenkins credentials
        self.jenkins_url = os.getenv('JENKINS_URL')
        self.jenkins_user = os.getenv('JENKINS_USER')
        self.jenkins_api_token = os.getenv('JENKINS_API_TOKEN')
        
        # JIRA credentials
        self.jira_server = os.getenv('JIRA_SERVER')
        self.jira_email = os.getenv('JIRA_EMAIL')
        self.jira_api_token = os.getenv('JIRA_API_TOKEN')
        
        # Validate credentials
        if not all([self.jenkins_url, self.jenkins_user, self.jenkins_api_token]):
            raise ValueError(
                "Missing Jenkins credentials. Please set JENKINS_URL, JENKINS_USER, "
                "and JENKINS_API_TOKEN in .env file"
            )
        
        if not all([self.jira_server, self.jira_email, self.jira_api_token]):
            raise ValueError(
                "Missing JIRA credentials. Please set JIRA_SERVER, JIRA_EMAIL, "
                "and JIRA_API_TOKEN in .env file"
            )
        
        # Setup authentication
        self.jenkins_auth = HTTPBasicAuth(self.jenkins_user, self.jenkins_api_token)
        
        # Connect to JIRA
        try:
            self.jira = JIRA(
                server=self.jira_server,
                basic_auth=(self.jira_email, self.jira_api_token)
            )
            print(f"✓ Connected to JIRA: {self.jira_server}")
        except Exception as e:
            raise ConnectionError(f"Failed to connect to JIRA: {str(e)}")
        
        # Create artifacts directory
        self.artifacts_dir = Path("jenkins_artifacts")
        self.artifacts_dir.mkdir(exist_ok=True)
    
    def fetch_artifacts(self, build_number):
        """Fetch all artifacts from Jenkins build"""
        print(f"\n{'='*60}")
        print(f"Fetching artifacts from Jenkins build #{build_number}")
        print(f"{'='*60}")
        
        # Construct Jenkins API URL
        api_url = f"{self.jenkins_url}/{build_number}/api/json"
        
        try:
            # Get build information
            # Disable SSL verification for self-signed certificates
            response = requests.get(api_url, auth=self.jenkins_auth, timeout=30, verify=False)
            response.raise_for_status()
            build_info = response.json()
            
            artifacts = build_info.get('artifacts', [])
            if not artifacts:
                print("⚠ No artifacts found in this build")
                return []
            
            print(f"✓ Found {len(artifacts)} artifact(s)")
            
            # Download each artifact
            downloaded_files = []
            for artifact in artifacts:
                file_name = artifact['fileName']
                relative_path = artifact['relativePath']
                
                # Construct download URL
                download_url = f"{self.jenkins_url}/{build_number}/artifact/{relative_path}"
                
                # Download file
                print(f"  Downloading: {file_name}...", end=" ")
                # Disable SSL verification for self-signed certificates
                file_response = requests.get(download_url, auth=self.jenkins_auth, timeout=60, verify=False)
                file_response.raise_for_status()
                
                # Save file
                local_path = self.artifacts_dir / file_name
                with open(local_path, 'wb') as f:
                    f.write(file_response.content)
                
                downloaded_files.append(local_path)
                print(f"✓ Saved to {local_path}")
            
            return downloaded_files
            
        except requests.exceptions.RequestException as e:
            raise Exception(f"Failed to fetch artifacts from Jenkins: {str(e)}")
    
    def parse_test_summary(self, test_summary_path):
        """Parse test-summary.txt and extract sections"""
        print(f"\n{'='*60}")
        print(f"Parsing test-summary.txt")
        print(f"{'='*60}")
        
        if not test_summary_path.exists():
            raise FileNotFoundError(f"test-summary.txt not found at {test_summary_path}")
        
        with open(test_summary_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Extract ODF Build version from first header
        odf_build_pattern = r'ODF Build:\s*([\d.]+(?:-\d+)?)'
        match = re.search(odf_build_pattern, content)
        
        if not match:
            raise ValueError("Could not extract ODF Build version from test-summary.txt")
        
        odf_build_full = match.group(1)  # e.g., "4.20.14-6"
        
        # Extract major.minor version (e.g., "4.20")
        version_parts = odf_build_full.split('.')
        odf_version = f"{version_parts[0]}.{version_parts[1]}"
        
        # Extract build number without the -N suffix (e.g., "4.20.14" from "4.20.14-6")
        # Split by '-' to remove the build suffix
        base_version = odf_build_full.split('-')[0]
        odf_summary = f"ODF {base_version}"
        
        print(f"✓ ODF Build: {odf_build_full}")
        print(f"✓ ODF Version: {odf_version}")
        print(f"✓ Summary: {odf_summary}")
        
        # Parse sections
        sections = self._extract_sections(content, odf_build_full)
        print(f"✓ Found {len(sections)} section(s)")
        
        return {
            'odf_build_full': odf_build_full,
            'odf_version': odf_version,
            'odf_summary': odf_summary,
            'sections': sections
        }
    
    def _extract_sections(self, content, odf_build):
        """Extract all sections from test-summary.txt"""
        sections = []
        
        # Pattern to match section headers
        header_pattern = r'={40,}\s*\n(ODF Build:.*?)\s*\n={40,}'
        
        # Find all headers
        headers = list(re.finditer(header_pattern, content))
        
        for i, header_match in enumerate(headers):
            header_text = header_match.group(1).strip()
            start_pos = header_match.end()
            
            # Find end position (start of next header or end of file)
            if i + 1 < len(headers):
                end_pos = headers[i + 1].start()
            else:
                end_pos = len(content)
            
            # Extract section content
            section_content = content[start_pos:end_pos].strip()
            
            # Create full section text with header
            full_section = f"{'='*40}\n{header_text}\n{'='*40}\n{section_content}"
            
            sections.append({
                'header': header_text,
                'content': section_content,
                'full_text': full_section
            })
        
        return sections
    
    def update_subtask_config(self, odf_version, odf_summary, due_date):
        """Update subtask_config.json with parsed information"""
        print(f"\n{'='*60}")
        print(f"Updating subtask_config.json")
        print(f"{'='*60}")
        
        config_path = Path("subtask_config.json")
        
        # Load existing config or create new one
        if config_path.exists():
            with open(config_path, 'r') as f:
                config = json.load(f)
            print(f"✓ Loaded existing config")
        else:
            # Load from example
            example_path = Path("subtask_config.json.example")
            if example_path.exists():
                with open(example_path, 'r') as f:
                    config = json.load(f)
                print(f"✓ Loaded config from example")
            else:
                config = {}
                print(f"✓ Creating new config")
        
        # Update config
        config['odf_version'] = odf_version
        config['summary'] = odf_summary
        # Only set due_date if provided, otherwise use empty string
        config['due_date'] = due_date if due_date else ""
        
        # Save config
        with open(config_path, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"✓ Updated subtask_config.json:")
        print(f"  - odf_version: {odf_version}")
        print(f"  - summary: {odf_summary}")
        print(f"  - due_date: {due_date if due_date else '(not set)'}")
        
        return config
    
    def create_jira_subtask(self):
        """Run create_jira_subtask.py to create the subtask"""
        print(f"\n{'='*60}")
        print(f"Creating JIRA subtask")
        print(f"{'='*60}")
        
        try:
            # Run the create_jira_subtask.py script
            # Set encoding to utf-8 for Windows compatibility
            result = subprocess.run(
                [sys.executable, 'create_jira_subtask.py'],
                capture_output=True,
                text=True,
                encoding='utf-8',
                errors='replace',
                check=True
            )
            
            print(result.stdout)
            
            # Extract subtask key from output - handle both creation and existing subtask cases
            # Pattern 1: "Subtask created successfully: CSOP-123"
            # Pattern 2: "already exists: CSOP-123"
            subtask_key_pattern = r'(?:Subtask created successfully|already exists):\s*([A-Z]+-\d+)'
            match = re.search(subtask_key_pattern, result.stdout)
            
            if match:
                subtask_key = match.group(1)
                print(f"✓ Subtask key: {subtask_key}")
                return subtask_key
            else:
                # Try alternative pattern for existing subtasks
                alt_pattern = r"'([A-Z]+-\d+)' already exists"
                alt_match = re.search(alt_pattern, result.stdout)
                if alt_match:
                    subtask_key = alt_match.group(1)
                    print(f"✓ Subtask key (existing): {subtask_key}")
                    return subtask_key
                raise Exception("Could not extract subtask key from output")
                
        except subprocess.CalledProcessError as e:
            print(f"✗ Error creating subtask: {e.stderr}")
            raise
    
    def add_comments_to_jira(self, subtask_key, sections):
        """Add each section as a comment to the JIRA subtask"""
        print(f"\n{'='*60}")
        print(f"Adding comments to JIRA subtask {subtask_key}")
        print(f"{'='*60}")
        
        try:
            issue = self.jira.issue(subtask_key)
            
            for i, section in enumerate(sections, 1):
                print(f"  Adding comment {i}/{len(sections)}: {section['header'][:50]}...")
                
                # Format comment with code block for better readability
                # Format comment with code block for better readability
                comment_text = f"{{code}}\n{section['full_text']}\n{{code}}"
                
                self.jira.add_comment(issue, comment_text)
                print(f"  ✓ Comment added")
            
            print(f"✓ Added {len(sections)} comment(s) to {subtask_key}")
            
        except Exception as e:
            raise Exception(f"Failed to add comments to JIRA: {str(e)}")
    
    def upload_attachment_to_jira(self, subtask_key, file_path):
        """Upload test-summary.txt as attachment to JIRA subtask"""
        print(f"\n{'='*60}")
        print(f"Uploading attachment to JIRA subtask {subtask_key}")
        print(f"{'='*60}")
        
        try:
            issue = self.jira.issue(subtask_key)
            
            with open(file_path, 'rb') as f:
                self.jira.add_attachment(issue=issue, attachment=f, filename=file_path.name)
            
            print(f"✓ Uploaded {file_path.name} to {subtask_key}")
            
        except Exception as e:
            raise Exception(f"Failed to upload attachment to JIRA: {str(e)}")
    
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
    
    def process(self, build_number, due_date):
        """Main processing workflow"""
        try:
            # Step 1: Fetch artifacts from Jenkins
            downloaded_files = self.fetch_artifacts(build_number)
            
            if not downloaded_files:
                raise Exception("No artifacts downloaded")
            
            # Step 2: Find test-summary*.txt and odf_tier_logs tar.gz
            test_summary_path = None
            tier_logs_tar_path = None
            
            for file_path in downloaded_files:
                if file_path.name.startswith('test-summary') and file_path.name.endswith('.txt'):
                    test_summary_path = file_path
                elif file_path.name.startswith('odf_tier_logs-') and file_path.name.endswith('.tar.gz'):
                    tier_logs_tar_path = file_path
            
            if not test_summary_path:
                raise FileNotFoundError("test-summary*.txt not found in artifacts")
            
            # Step 3: Parse test-summary.txt
            parsed_data = self.parse_test_summary(test_summary_path)
            
            # Step 4: Update subtask_config.json
            self.update_subtask_config(
                parsed_data['odf_version'],
                parsed_data['odf_summary'],
                due_date
            )
            
            # Step 5: Create JIRA subtask
            subtask_key = self.create_jira_subtask()
            
            # Step 6: Add comments to JIRA
            self.add_comments_to_jira(subtask_key, parsed_data['sections'])
            
            # Step 7: Upload test-summary.txt as attachment
            self.upload_attachment_to_jira(subtask_key, test_summary_path)
            
            # Step 8: Upload odf_tier_logs tar.gz if found
            if tier_logs_tar_path:
                self.upload_attachment_to_jira(subtask_key, tier_logs_tar_path)
            else:
                print(f"⚠ Warning: odf_tier_logs-*.tar.gz not found in artifacts")
            
            # Step 9: Cleanup artifacts
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
            raise


def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description='Fetch Jenkins artifacts and create JIRA subtask with test results',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python fetch_jenkins_artifacts.py --build-number 123
    python fetch_jenkins_artifacts.py --build-number 123 --due-date "17/Jun/26"
    python fetch_jenkins_artifacts.py -b 456 -d "20/Dec/26"

Environment Variables Required (.env file):
    JENKINS_URL - Jenkins job URL
    JENKINS_USER - Jenkins username
    JENKINS_API_TOKEN - Jenkins API token
    JIRA_SERVER - JIRA server URL
    JIRA_EMAIL - JIRA email
    JIRA_API_TOKEN - JIRA API token
        """
    )
    
    parser.add_argument(
        '-b', '--build-number',
        required=True,
        type=int,
        help='Jenkins build number to fetch artifacts from'
    )
    
    parser.add_argument(
        '-d', '--due-date',
        required=False,
        default=None,
        help='Due date for JIRA subtask (format: d/MMM/yy, e.g., 17/Jun/26). Optional.'
    )
    
    args = parser.parse_args()
    
    # Handle empty string as None
    due_date = args.due_date if args.due_date and args.due_date.strip() else None
    
    try:
        fetcher = JenkinsArtifactFetcher()
        fetcher.process(args.build_number, due_date)
        return 0
        
    except Exception as e:
        print(f"\n✗ Fatal Error: {str(e)}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())

# Made with Bob
