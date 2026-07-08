#!/usr/bin/env python3
"""
JIRA Utility Functions

Shared utilities for JIRA integration used by multiple scripts.
"""

import os
import sys
import json
import re
import subprocess
from pathlib import Path
from dotenv import load_dotenv
from jira import JIRA
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload


class JiraHelper:
    """Helper class for JIRA operations"""
    
    def __init__(self):
        """Initialize JIRA connection"""
        load_dotenv()
        
        # JIRA credentials
        self.jira_server = os.getenv('JIRA_SERVER')
        self.jira_email = os.getenv('JIRA_EMAIL')
        self.jira_api_token = os.getenv('JIRA_API_TOKEN')
        
        # Validate credentials
        if not all([self.jira_server, self.jira_email, self.jira_api_token]):
            raise ValueError(
                "Missing JIRA credentials. Please set JIRA_SERVER, JIRA_EMAIL, "
                "and JIRA_API_TOKEN in .env file"
            )
        
        # Connect to JIRA
        try:
            self.jira = JIRA(
                server=self.jira_server,
                basic_auth=(self.jira_email, self.jira_api_token)
            )
            print(f"✓ Connected to JIRA: {self.jira_server}")
        except Exception as e:
            raise ConnectionError(f"Failed to connect to JIRA: {str(e)}")
    
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
            # Run the create_jira_subtask.py script from scripts directory
            script_path = Path(__file__).parent / 'create_jira_subtask.py'
            result = subprocess.run(
                [sys.executable, str(script_path)],
                capture_output=True,
                text=True,
                encoding='utf-8',
                errors='replace',
                check=True
            )
            
            print(result.stdout)
            
            # Extract subtask key from output
            subtask_key_pattern = r'(?:Subtask created successfully|already exists):\s*([A-Z]+-\d+)'
            match = re.search(subtask_key_pattern, result.stdout)
            
            if match:
                subtask_key = match.group(1)
                print(f"✓ Subtask key: {subtask_key}")
                return subtask_key
            else:
                # Try alternative pattern
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
    
    def add_comments_to_jira(self, subtask_key, sections, skip_if_exists=False):
        """Add each section as a comment to the JIRA subtask"""
        print(f"\n{'='*60}")
        print(f"Adding comments to JIRA subtask {subtask_key}")
        print(f"{'='*60}")
        
        try:
            issue = self.jira.issue(subtask_key)
            
            # Check if comments already exist
            if skip_if_exists:
                existing_comments = self.jira.comments(issue)
                if existing_comments:
                    print(f"✓ Found {len(existing_comments)} existing comment(s)")
                    print(f"  Skipping comment addition (already added)")
                    return
            
            for i, section in enumerate(sections, 1):
                print(f"  Adding comment {i}/{len(sections)}: {section['header'][:50]}...")
                
                # Format comment with code block for better readability
                comment_text = f"{{code}}\n{section['full_text']}\n{{code}}"
                
                self.jira.add_comment(issue, comment_text)
                print(f"  ✓ Comment added")
            
            print(f"✓ Added {len(sections)} comment(s) to {subtask_key}")
            
        except Exception as e:
            raise Exception(f"Failed to add comments to JIRA: {str(e)}")
    
    def upload_attachment_to_jira(self, subtask_key, file_path, skip_if_exists=False):
        """Upload file as attachment to JIRA subtask"""
        print(f"\n{'='*60}")
        print(f"Uploading attachment to JIRA subtask {subtask_key}")
        print(f"{'='*60}")
        
        try:
            issue = self.jira.issue(subtask_key)
            
            # Check if attachment already exists
            if skip_if_exists:
                existing_attachments = issue.fields.attachment
                for attachment in existing_attachments:
                    if attachment.filename == file_path.name:
                        print(f"✓ Attachment '{file_path.name}' already exists")
                        print(f"  Skipping upload (already attached)")
                        return
            
            with open(file_path, 'rb') as f:
                self.jira.add_attachment(issue=issue, attachment=f, filename=file_path.name)
            
            print(f"✓ Uploaded {file_path.name} to {subtask_key}")
            
        except Exception as e:
            raise Exception(f"Failed to upload attachment to JIRA: {str(e)}")


# ---------------------------------------------------------------------------
# Google Drive Helper
# ---------------------------------------------------------------------------

_GDRIVE_SCOPES = ['https://www.googleapis.com/auth/drive']


def _get_oauth_credentials(client_secrets_file, token_file, force_reauth=False):
    """
    Return valid OAuth2 user credentials, refreshing or re-running the consent
    flow as needed.  Token is cached to disk so the browser only opens once.
    """
    token_path = Path(token_file)
    creds = None

    if not force_reauth and token_path.exists():
        creds = Credentials.from_authorized_user_file(str(token_path), _GDRIVE_SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            print("  Refreshing expired Google OAuth token...")
            creds.refresh(Request())
        else:
            if not Path(client_secrets_file).exists():
                raise FileNotFoundError(
                    f"OAuth client secrets file not found: {client_secrets_file}\n\n"
                    "One-time setup:\n"
                    "  1. https://console.cloud.google.com/ → APIs & Services → "
                    "Enable 'Google Drive API'\n"
                    "  2. Credentials → Create Credentials → OAuth client ID "
                    "(Desktop app)\n"
                    "  3. Download JSON → save as: oauth_client_secrets.json\n"
                    "     (or set GDRIVE_OAUTH_CLIENT_FILE in .env)"
                )
            print("  Opening browser for Google OAuth consent...")
            flow = InstalledAppFlow.from_client_secrets_file(
                client_secrets_file, _GDRIVE_SCOPES
            )
            creds = flow.run_local_server(port=0)
            print("  ✓ Authentication successful")

        token_path.write_text(creds.to_json())
        print(f"  ✓ Token cached to {token_path}")

    return creds


class GDriveHelper:
    """
    Google Drive helper used by fetch_jenkins_artifacts.py and
    fetch_bastion_artifacts.py to upload must-gather archives.

    Authentication uses OAuth 2.0 (installed-app / user-credentials flow) so
    uploads run under your own Google account — the same account that already
    has access to the shared folder.

    On first use a browser window opens for a one-time consent screen.
    The token is cached locally and silently refreshed on every subsequent run.

    Required .env variables:
        GOOGLE_DRIVE_PARENT_FOLDER_ID   Parent folder ID in Google Drive
        GDRIVE_OAUTH_CLIENT_FILE        Path to OAuth client secrets JSON
                                        (default: oauth_client_secrets.json)
        GDRIVE_OAUTH_TOKEN_FILE         Path to cached token file
                                        (default: .gdrive_oauth_token.json)
    """

    def __init__(self, force_reauth=False):
        load_dotenv()

        self.parent_folder_id = os.getenv('GOOGLE_DRIVE_PARENT_FOLDER_ID')
        if not self.parent_folder_id:
            raise ValueError("Missing GOOGLE_DRIVE_PARENT_FOLDER_ID in .env file")

        client_secrets_file = os.getenv(
            'GDRIVE_OAUTH_CLIENT_FILE', 'oauth_client_secrets.json'
        )
        token_file = os.getenv(
            'GDRIVE_OAUTH_TOKEN_FILE', '.gdrive_oauth_token.json'
        )

        print("Authenticating with Google Drive (OAuth)...")
        creds = _get_oauth_credentials(client_secrets_file, token_file, force_reauth)
        self.service = build('drive', 'v3', credentials=creds)
        print("✓ Connected to Google Drive as your user account")

    def get_or_create_folder(self, folder_name):
        """Return the ID of an existing Drive sub-folder, or create it."""
        query = (
            f"name='{folder_name}' "
            f"and '{self.parent_folder_id}' in parents "
            f"and mimeType='application/vnd.google-apps.folder' "
            f"and trashed=false"
        )
        results = self.service.files().list(
            q=query, spaces='drive', fields='files(id, name)'
        ).execute()

        folders = results.get('files', [])
        if folders:
            folder_id = folders[0]['id']
            print(f"  ✓ Found existing folder: {folder_name} (ID: {folder_id})")
            return folder_id

        file_metadata = {
            'name': folder_name,
            'mimeType': 'application/vnd.google-apps.folder',
            'parents': [self.parent_folder_id]
        }
        folder = self.service.files().create(
            body=file_metadata, fields='id'
        ).execute()
        folder_id = folder.get('id')
        print(f"  ✓ Created new folder: {folder_name} (ID: {folder_id})")
        return folder_id

    def upload_file(self, file_path, folder_id):
        """Upload a single file to the given Drive folder."""
        file_metadata = {'name': file_path.name, 'parents': [folder_id]}
        media = MediaFileUpload(str(file_path), resumable=True)
        result = self.service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id, webViewLink'
        ).execute()
        print(f"  ✓ Uploaded: {file_path.name}")
        print(f"    File ID : {result.get('id')}")
        print(f"    Link    : {result.get('webViewLink', 'N/A')}")

    def upload_must_gather(self, odf_build_full, artifacts_dir):
        """
        Upload must-gather-*.tar.gz from artifacts_dir to a version-specific
        folder (e.g. ZS-4.17.29) inside the configured parent folder.

        The local file is deleted ONLY after a confirmed successful upload.

        Args:
            odf_build_full : full build string, e.g. '4.17.29-1'
            artifacts_dir  : Path object pointing at the local artifacts directory
        """
        print(f"\n{'='*60}")
        print(f"Uploading must-gather to Google Drive")
        print(f"{'='*60}")

        # "4.17.29-1" → "ZS-4.17.29"
        version_base = odf_build_full.split('-')[0]
        folder_name = f"ZS-{version_base}"
        print(f"  ODF Build   : {odf_build_full}")
        print(f"  Folder Name : {folder_name}")

        must_gather_files = list(Path(artifacts_dir).glob('must-gather-*.tar.gz'))
        if not must_gather_files:
            print(f"  ⚠ No must-gather-*.tar.gz found in {artifacts_dir}, skipping")
            return

        must_gather_path = must_gather_files[0]
        print(f"  Uploading   : {must_gather_path.name}")

        folder_id = self.get_or_create_folder(folder_name)
        self.upload_file(must_gather_path, folder_id)

        # Delete local file only after confirmed upload
        must_gather_path.unlink()
        print(f"  ✓ Deleted local file: {must_gather_path.name}")
        print(f"✓ Must-gather uploaded successfully to Google Drive folder '{folder_name}'")


# Made with Bob