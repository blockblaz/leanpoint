#!/usr/bin/env python3
"""
Convert validator-config.yaml to upstreams.json for leanpoint.

This script reads a validator-config.yaml file (used by lean-quickstart)
and generates an upstreams.json file that leanpoint can use to monitor
multiple lean nodes.

Usage:
    python3 convert-validator-config.py [validator-config.yaml] [output.json]

Example:
    python3 convert-validator-config.py \
        ../lean-quickstart/local-devnet/genesis/validator-config.yaml \
        upstreams.json
"""

import sys
import json
import yaml


def convert_validator_config(yaml_path: str, output_path: str, base_port: int = 8081):
    """
    Convert validator-config.yaml to upstreams.json.
    
    Args:
        yaml_path: Path to validator-config.yaml
        output_path: Path to output upstreams.json
        base_port: Base HTTP port for beacon API (default: 5052)
    """
    with open(yaml_path, 'r') as f:
        config = yaml.safe_load(f)
    
    if 'validators' not in config:
        print("Error: No 'validators' key found in config", file=sys.stderr)
        sys.exit(1)
    
    upstreams = []
    
    for idx, validator in enumerate(config['validators']):
        name = validator.get('name', f'validator_{idx}')
        
        # Try to get IP from enrFields, default to localhost
        ip = "127.0.0.1"
        if 'enrFields' in validator and 'ip' in validator['enrFields']:
            ip = validator['enrFields']['ip']
        
        # Calculate HTTP port (base_port + index)
        # This is a reasonable default; adjust if your setup differs
        http_port = base_port + idx
        
        upstream = {
            "name": name,
            "url": f"http://{ip}:{http_port}",
            "path": "/health"  # Health check endpoint
        }
        
        upstreams.append(upstream)
    
    output = {"upstreams": upstreams}
    
    with open(output_path, 'w') as f:
        json.dump(output, f, indent=2)
    
    print(f"✅ Converted {len(upstreams)} validators to {output_path}")
    print(f"\nGenerated upstreams:")
    for u in upstreams:
        print(f"  - {u['name']}: {u['url']}{u['path']}")
    
    print(f"\n💡 To use: leanpoint --upstreams-config {output_path}")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        print("\nUsing default paths...")
        yaml_path = "../lean-quickstart/local-devnet/genesis/validator-config.yaml"
        output_path = "upstreams.json"
    elif len(sys.argv) == 2:
        yaml_path = sys.argv[1]
        output_path = "upstreams.json"
    else:
        yaml_path = sys.argv[1]
        output_path = sys.argv[2]
    
    try:
        convert_validator_config(yaml_path, output_path)
    except FileNotFoundError as e:
        print(f"Error: File not found: {e}", file=sys.stderr)
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"Error: Invalid YAML: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
