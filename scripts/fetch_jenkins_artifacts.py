#!/usr/bin/env python3
"""
Jenkins Artifact Fetcher and JIRA Integration Script

This script fetches artifacts from Jenkins builds, parses test-summary.txt,
updates subtask_config.json, creates JIRA subtasks, adds comments with test results,
uploads test-summary.txt and odf_tier_logs-*.tar.gz as JIRA attachments,
and uploads must-gather to Google Drive in version-specific folders.

Usage:
    python fetch_jenkins_artifacts.py --build-number 123 [--due-date "17/Jun/26"]
    python fetch_jenkins_artifacts.py --build-number 123
"""

import os
import sys
import argparse
import shutil
from pathlib import Path
import requests
from requests.auth import HTTPBasicAuth
from dotenv import load_dotenv
import urllib3
from jira_utils import JiraHelper, GDriveHelper

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

        if not all([self.jenkins_url, self.jenkins_user, self.jenkins_api_token]):
            raise ValueError(
                "Missing Jenkins credentials. Please set JENKINS_URL, JENKINS_USER, "
                "and JENKINS_API_TOKEN in .env file"
            )

        self.jenkins_auth = HTTPBasicAuth(self.jenkins_user, self.jenkins_api_token)

        # Initialize JIRA helper
        self.jira_helper = JiraHelper()
        self.jira_server = self.jira_helper.jira_server

        # Initialize Google Drive helper (optional — skipped if not configured)
        self.gdrive_helper = None
        if os.getenv('GOOGLE_DRIVE_PARENT_FOLDER_ID'):
            try:
                self.gdrive_helper = GDriveHelper()
            except Exception as e:
                print(f"⚠ Warning: Could not connect to Google Drive: {e}")
                print(f"  Must-gather will not be uploaded to Google Drive")
        else:
            print("⚠ GOOGLE_DRIVE_PARENT_FOLDER_ID not set — Google Drive upload skipped")

        # Create artifacts directory
        self.artifacts_dir = Path("jenkins_artifacts")
        self.artifacts_dir.mkdir(exist_ok=True)

    def fetch_artifacts(self, build_number, skip_if_exists=False):
        """Fetch all artifacts from Jenkins build"""
        print(f"\n{'='*60}")
        print(f"Fetching artifacts from Jenkins build #{build_number}")
        print(f"{'='*60}")

        # Check if artifacts already exist locally
        if skip_if_exists and self.artifacts_dir.exists():
            existing_files = list(self.artifacts_dir.glob('*'))
            if existing_files:
                print(f"✓ Found {len(existing_files)} existing artifact(s) in {self.artifacts_dir}")
                print(f"  Skipping download (using cached artifacts)")
                return existing_files

        api_url = f"{self.jenkins_url}/{build_number}/api/json"

        try:
            response = requests.get(api_url, auth=self.jenkins_auth, timeout=30, verify=False)
            response.raise_for_status()
            build_info = response.json()

            artifacts = build_info.get('artifacts', [])
            if not artifacts:
                print("⚠ No artifacts found in this build")
                return []

            print(f"✓ Found {len(artifacts)} artifact(s) in Jenkins")

            downloaded_files = []
            for artifact in artifacts:
                file_name = artifact['fileName']
                relative_path = artifact['relativePath']
                local_path = self.artifacts_dir / file_name

                if skip_if_exists and local_path.exists():
                    print(f"  ✓ {file_name} already exists, skipping download")
                    downloaded_files.append(local_path)
                    continue

                download_url = f"{self.jenkins_url}/{build_number}/artifact/{relative_path}"

                print(f"  Downloading: {file_name}...", end=" ", flush=True)

                with requests.get(download_url, auth=self.jenkins_auth, timeout=300,
                                  verify=False, stream=True) as file_response:
                    file_response.raise_for_status()
                    total_size = int(file_response.headers.get('content-length', 0))

                    with open(local_path, 'wb') as f:
                        downloaded = 0
                        for chunk in file_response.iter_content(chunk_size=8192):
                            if chunk:
                                f.write(chunk)
                                downloaded += len(chunk)
                                if total_size > 1024 * 1024:
                                    progress = (downloaded / total_size * 100) if total_size > 0 else 0
                                    print(f"\r  Downloading: {file_name}... {progress:.1f}%",
                                          end="", flush=True)

                    if total_size > 1024 * 1024:
                        print(f"\r  Downloading: {file_name}... ", end="")

                downloaded_files.append(local_path)
                print(f"✓ Saved to {local_path}")

            return downloaded_files

        except requests.exceptions.RequestException as e:
            raise Exception(f"Failed to fetch artifacts from Jenkins: {str(e)}")

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

    def process(self, build_number, due_date, resume=False):
        """Main processing workflow with optional resume capability"""
        subtask_key = None
        all_steps_successful = False

        try:
            # Step 1: Fetch artifacts from Jenkins
            downloaded_files = self.fetch_artifacts(build_number, skip_if_exists=resume)

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
            self.jira_helper.add_comments_to_jira(
                subtask_key, parsed_data['sections'], skip_if_exists=resume
            )

            # Step 7: Upload test-summary.txt as attachment using JiraHelper
            self.jira_helper.upload_attachment_to_jira(
                subtask_key, test_summary_path, skip_if_exists=resume
            )

            # Step 8: Upload odf_tier_logs tar.gz if found using JiraHelper
            if tier_logs_tar_path:
                self.jira_helper.upload_attachment_to_jira(
                    subtask_key, tier_logs_tar_path, skip_if_exists=resume
                )
            else:
                print(f"⚠ Warning: odf_tier_logs-*.tar.gz not found in artifacts")

            # Step 9: Upload must-gather to Google Drive (optional)
            if self.gdrive_helper:
                self.gdrive_helper.upload_must_gather(
                    parsed_data['odf_build_full'], self.artifacts_dir
                )
            else:
                print(f"\n{'='*60}")
                print(f"⚠ Google Drive upload skipped (not configured)")
                print(f"{'='*60}")

            # Mark all steps as successful
            all_steps_successful = True

            # Step 10: Cleanup artifacts only if all steps succeeded
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

Optional (Google Drive upload):
    GOOGLE_DRIVE_PARENT_FOLDER_ID - Parent folder ID in Google Drive
    GDRIVE_OAUTH_CLIENT_FILE - Path to OAuth client secrets JSON (default: oauth_client_secrets.json)
    GDRIVE_OAUTH_TOKEN_FILE - Path to cached token file (default: .gdrive_oauth_token.json)
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

    parser.add_argument(
        '-r', '--resume',
        action='store_true',
        help='Resume from previous run, skip already completed steps'
    )

    args = parser.parse_args()

    due_date = args.due_date if args.due_date and args.due_date.strip() else None

    try:
        fetcher = JenkinsArtifactFetcher()
        fetcher.process(args.build_number, due_date, resume=args.resume)
        return 0

    except Exception as e:
        print(f"\n✗ Fatal Error: {str(e)}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())

# Made with Bob
