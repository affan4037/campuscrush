#!/usr/bin/env python
import json
import os
import re
import sys
import ipaddress

# Validate the IP address format
def validate_ip(ip):
    try:
        ipaddress.ip_address(ip)
        return True
    except ValueError:
        return False

# Update a file with new IP addresses
def update_file(file_path, regex_patterns, replacements, encoding='utf-8'):
    """
    Update a file with new IP information using regex patterns.
    
    Args:
        file_path: Path to the file to update
        regex_patterns: Dictionary of regex patterns to match for replacement
        replacements: Dictionary of replacement values
        encoding: File encoding to use
    
    Returns:
        bool: Whether any updates were made to the file
    """
    if not os.path.exists(file_path):
        print(f"⚠️ File not found: {file_path}")
        return False
        
    print(f"\nProcessing: {file_path}")
    updated = False
    
    # Try with the provided encoding, fall back to latin-1 if needed
    for current_encoding in [encoding, 'latin-1']:
        try:
            with open(file_path, 'r', encoding=current_encoding) as f:
                content = f.read()
                
            original_content = content
            
            # Apply each regex pattern and replacement
            for pattern_name, pattern in regex_patterns.items():
                replacement = replacements.get(pattern_name, "")
                if not replacement:
                    continue
                    
                new_content = re.sub(pattern, replacement, content)
                if new_content != content:
                    content = new_content
                    updated = True
                    print(f"  - Updated {pattern_name} to {replacement}")
            
            # Only write the file if changes were made
            if updated:
                with open(file_path, 'w', encoding=current_encoding) as f:
                    f.write(content)
                encoding_info = "" if current_encoding == 'utf-8' else f" (using {current_encoding} encoding)"
                print(f"✅ Successfully updated {file_path}{encoding_info}")
                return True
            else:
                print(f"ℹ️ No changes needed in {file_path}")
                return False
                
            # If we get here with the first encoding, we didn't encounter an error
            break
                
        except UnicodeDecodeError:
            # If we're already trying the fallback encoding, let the exception propagate
            if current_encoding != encoding:
                raise
            # Otherwise, we'll try again with latin-1
            continue
        except Exception as e:
            print(f"⚠️ Error updating {file_path}: {e}")
            return False
            
    return False

def update_ip_configuration(new_ip=None, backend_port=None, frontend_port=None):
    """
    Update IP configuration across all relevant project files.
    
    Args:
        new_ip: New IP address to set
        backend_port: Backend server port
        frontend_port: Frontend server port
        
    Returns:
        bool: Whether the update was successful
    """
    # Read the current configuration
    try:
        with open('ip_config.json', 'r') as f:
            config = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        print("Error: ip_config.json file not found or invalid.")
        print("Creating default configuration...")
        config = {
            "SERVER_IP": "192.168.10.2", 
            "BACKEND_PORT": 8000,
            "FRONTEND_PORT": 3000
        }
    
    # Update with new values if provided
    if new_ip and validate_ip(new_ip):
        config["SERVER_IP"] = new_ip
    elif new_ip:
        print(f"Error: '{new_ip}' is not a valid IP address.")
        return False
    
    if backend_port and backend_port.isdigit():
        config["BACKEND_PORT"] = int(backend_port)
    
    if frontend_port and frontend_port.isdigit():
        config["FRONTEND_PORT"] = int(frontend_port)
    
    # Save the updated configuration
    with open('ip_config.json', 'w') as f:
        json.dump(config, f, indent=2)
    
    # Get values for substitution
    server_ip = config["SERVER_IP"]
    backend_port = config["BACKEND_PORT"]
    frontend_port = config["FRONTEND_PORT"]
    
    backend_url = f"http://{server_ip}:{backend_port}"
    frontend_url = f"http://{server_ip}:{frontend_port}"
    
    print(f"\nUpdating configurations with:")
    print(f"Server IP: {server_ip}")
    print(f"Backend URL: {backend_url}")
    print(f"Frontend URL: {frontend_url}")
    print("-" * 50)
    
    # Track updated files
    updated_files = 0
    
    # Define replacements to use across files
    replacements = {
        "baseUrl": backend_url,
        "serverIp": server_ip,
        "frontendUrl": frontend_url
    }
    
    # Update frontend Flutter app constants
    flutter_constants_patterns = {
        "baseUrl": r'static const String baseUrl = [\'"]http://[^:]+:[0-9]+[\'"];',
        "serverIp": r'// Your IP address is [0-9.]+',
        "fallbackUrl": r'\'http://[^:]+:[0-9]+\', // Current IP',
        "commonServerIps": r'''static const List<String> commonServerIps = \[
    '[^']+',
    '[^']+',
    '[^']+',
    '[^']+',
  \];''',
        "fallbackBaseUrls": r'''static const List<String> fallbackBaseUrls = \[
    "[^"]+",
    '[^']+',
  \];'''
    }
    
    flutter_constants_replacements = {
        "baseUrl": f'static const String baseUrl = "{backend_url}";',
        "serverIp": f"// Your IP address is {server_ip}",
        "fallbackUrl": f"'{backend_url}', // Current IP",
        "commonServerIps": f'''static const List<String> commonServerIps = [
    '{server_ip}',
    '192.168.10.2',
    '192.168.10.4',
    '10.0.2.2',
  ];''',
        "fallbackBaseUrls": f'''static const List<String> fallbackBaseUrls = [
    "https://honest-perfection-production-ccc8.up.railway.app",
    'http://{server_ip}:{backend_port}',
  ];'''
    }
    
    if update_file(
        "frontend_campuscrush/lib/core/constants/app_constants.dart",
        flutter_constants_patterns,
        flutter_constants_replacements
    ):
        updated_files += 1
    
    # Update backend .env file
    env_patterns = {
        "baseUrl": r'BASE_URL=http://[^:]+:[0-9]+',
        "frontendUrl": r'FRONTEND_URL=http://[^:]+:[0-9]+'
    }
    
    env_replacements = {
        "baseUrl": f"BASE_URL={backend_url}",
        "frontendUrl": f"FRONTEND_URL={frontend_url}"
    }
    
    if update_file("backend_campuscrush/.env", env_patterns, env_replacements):
        updated_files += 1
    
    # Update backend config.py file
    config_patterns = {
        "baseUrl": r'BASE_URL: str = os.getenv\("BASE_URL", "http://[^:]+:[0-9]+"\)',
        "frontendUrl": r'FRONTEND_URL: str = os.getenv\("FRONTEND_URL", "http://[^:]+:[0-9]+"\)',
        "corsUrl": r'"http://[^:]+:[0-9]+",  # Frontend on same network'
    }
    
    config_replacements = {
        "baseUrl": f'BASE_URL: str = os.getenv("BASE_URL", "{backend_url}")',
        "frontendUrl": f'FRONTEND_URL: str = os.getenv("FRONTEND_URL", "{frontend_url}")',
        "corsUrl": f'"{frontend_url}",  # Frontend on same network'
    }
    
    if update_file("backend_campuscrush/app/core/config.py", config_patterns, config_replacements):
        updated_files += 1
    
    # Summary of updates
    print("\n" + "=" * 50)
    print(f"✅ Update complete! Modified {updated_files} file(s).")
    if updated_files > 0:
        print(f"IP configuration updated to: {server_ip}")
        print(f"Backend URL: {backend_url}")
        print(f"Frontend URL: {frontend_url}")
    else:
        print("No files were modified. All configurations were already up to date.")
    
    return True

def main():
    """
    Main entry point for the IP update script.
    Handles command line arguments and auto-detection of IP.
    """
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python update_ip.py <ip_address> [backend_port] [frontend_port]")
        print("  python update_ip.py auto (to detect IP automatically)")
        return
    
    if sys.argv[1].lower() == "auto":
        try:
            import socket
            hostname = socket.gethostname()
            ip = socket.gethostbyname(hostname)
            print(f"Detected IP address: {ip}")
            new_ip = ip
        except Exception as e:
            print(f"Error detecting IP automatically: {e}")
            print("Please provide the IP address manually.")
            return
    else:
        new_ip = sys.argv[1]
    
    backend_port = sys.argv[2] if len(sys.argv) > 2 else None
    frontend_port = sys.argv[3] if len(sys.argv) > 3 else None
    
    update_ip_configuration(new_ip, backend_port, frontend_port)

if __name__ == "__main__":
    main() 