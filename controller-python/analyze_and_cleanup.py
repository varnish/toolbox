#!/usr/bin/env python3
# must run vcli.py with configuration (follow readme instructions)
# cleanup_analysis.py
# Analyzes VCL Groups and Files to identify unreferenced files

import vcli
import requests

def delete_unreferenced_files(v, file_ids, file_lookup):
    """
    Delete files by their IDs using the API
    """
    deleted_count = 0
    failed_deletions = []
    
    for file_id in sorted(file_ids):
        file_name = file_lookup.get(file_id, f"Unknown file (ID: {file_id})")
        print(f"  Deleting: {file_name} (ID: {file_id})...")
        
        try:
            # Attempt to delete the file using DELETE request
            endpoint = f"/files/{file_id}"
            url = f"{v.endpoint}{endpoint}"
            
            # Ensure we have a valid token
            token = v.refresh_token()
            headers = {"Authorization": f"Bearer {token}"}
            
            response = requests.delete(url, headers=headers, timeout=30)
            
            if response.status_code == 200 or response.status_code == 204:
                print(f" Successfully deleted: {file_name}")
                deleted_count += 1
            else:
                print(f" Failed to delete: {file_name} (HTTP {response.status_code})")
                failed_deletions.append((file_id, file_name, response.status_code))
                
        except requests.RequestException as e:
            print(f" Error deleting {file_name}: {e}")
            failed_deletions.append((file_id, file_name, str(e)))
    
    print("\nDeletion Summary:")
    print(f"  Successfully deleted: {deleted_count} files")
    if failed_deletions:
        print(f"  Failed deletions: {len(failed_deletions)} files")
        for file_id, file_name, error in failed_deletions:
            print(f"    - {file_name} (ID: {file_id}): {error}")

def main():
    # Initialize the Vcli client which will handle token management
    v = vcli.Vcli.from_yaml("config.yaml")
    
    # Ensure we have a valid token before making API calls
    token = v.refresh_token()
    if not token:
        print("Failed to obtain access token")
        return
    
    print(f"Successfully authenticated. Token expires at: {v.accessExpire}")
    print("=" * 60)
    
    # Get all VCL Groups with detailed information
    print("Fetching VCL Groups...")
    groups = v.query_endpoint("/vclgroups") or []
    print(f"\nVCL Groups ({len(groups)}):")
    print("-" * 40)
    
    # Track all file IDs referenced by VCL Groups
    referenced_files = set()
    
    for group in groups:
        group_id = group.get('id')
        group_name = group.get('name')
        print(f"\nGroup: {group_name} (ID: {group_id})")
        
        # Get detailed information for this VCL Group
        group_detail = v.query_endpoint(f"/vclgroups/{group_id}")
        if group_detail:
            # Extract file references from mainVCL
            if 'mainVCL' in group_detail and group_detail['mainVCL']:
                main_vcl = group_detail['mainVCL']
                if isinstance(main_vcl, dict) and 'fileId' in main_vcl:
                    file_id = main_vcl['fileId']
                    referenced_files.add(file_id)
                    print(f"  mainVCL references file: {main_vcl.get('name')} (ID: {file_id})")
            
            # Extract file references from includes
            if 'includes' in group_detail and group_detail['includes']:
                includes = group_detail['includes']
                if isinstance(includes, list):
                    for include in includes:
                        if isinstance(include, dict) and 'fileId' in include:
                            file_id = include['fileId']
                            referenced_files.add(file_id)
                            print(f"  include references file: {include.get('name')} (ID: {file_id})")
    
    print("\n" + "=" * 60)
    
    # Get all Files
    print("Fetching Files...")
    files = v.query_endpoint("/files") or []
    print(f"\nAll Files ({len(files)}):")
    print("-" * 40)
    
    all_file_ids = set()
    file_lookup = {}
    
    for file in files:
        file_id = file.get('id')
        file_name = file.get('name')
        all_file_ids.add(file_id)
        file_lookup[file_id] = file_name
        print(f"  {file_name} (ID: {file_id})")
    
    print("\n" + "=" * 60)
    
    # Identify referenced vs unreferenced files
    print("File Reference Analysis:")
    print("-" * 40)
    
    print(f"\nReferenced File IDs: {sorted(referenced_files)}")
    unreferenced_files = all_file_ids - referenced_files
    
    print(f"\nReferenced Files ({len(referenced_files)}):")
    for file_id in sorted(referenced_files):
        if file_id in file_lookup:
            print(f"  ✓ {file_lookup[file_id]} (ID: {file_id})")
        else:
            print(f"  ✗ Unknown file (ID: {file_id}) - referenced but not found!")
    
    print(f"\nUnreferenced Files ({len(unreferenced_files)}):")
    if unreferenced_files:
        print("  WARNING: The following files are not referenced by any VCL Group!")
        print("  They could potentially be deleted:")
        print()
        for file_id in sorted(unreferenced_files):
            print(f"  {file_lookup[file_id]} (ID: {file_id})")
        
        # Ask user if they want to delete these files
        print("\n" + "=" * 60)
        print(" DELETION CONFIRMATION ")
        print("=" * 60)
        print(f"Found {len(unreferenced_files)} unreferenced files that could be deleted.")
        print("\nWARNING: This action cannot be undone!")
        print("Files to be deleted:")
        for file_id in sorted(unreferenced_files):
            print(f"  - {file_lookup[file_id]} (ID: {file_id})")
        
        deletion_performed = False
        while True:
            response = input(f"\nDo you want to delete these {len(unreferenced_files)} files? (yes/no): ").strip().lower()
            if response in ['yes', 'y']:
                print("\nProceeding with deletion...")
                delete_unreferenced_files(v, unreferenced_files, file_lookup)
                deletion_performed = True
                break
            elif response in ['no', 'n']:
                print("\nDeletion cancelled. No files were deleted.")
                break
            else:
                print("Please enter 'yes' or 'no'")
        
        # Update summary based on user choice
        if deletion_performed:
            summary_msg = f"Found {len(unreferenced_files)} unreferenced files. Deletion attempted."
        else:
            summary_msg = f"Found {len(unreferenced_files)} unreferenced files. No deletions performed."
    else:
        print("  All files are referenced by at least one VCL Group.")
        summary_msg = "No unreferenced files found. All files are in use."
    
    print("\n" + "=" * 60)
    print("Analysis Complete!")
    print(f"\nSUMMARY: {summary_msg}")

if __name__ == "__main__":
    main()