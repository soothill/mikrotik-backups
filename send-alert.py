#!/usr/bin/env python3
"""
Email alert sender for MikroTik backup failures.
Reads configuration from config.yml and sends email notifications.
"""

import sys
import smtplib
import socket
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(1)


def load_config():
    """Load email configuration from config.yml"""
    config_file = Path(__file__).parent / "config.yml"

    if not config_file.exists():
        print(f"Error: Configuration file not found: {config_file}", file=sys.stderr)
        return None

    with open(config_file, 'r') as f:
        config = yaml.safe_load(f)

    # Check if email alerts are configured and enabled
    if 'email_alerts' not in config:
        return None

    email_config = config['email_alerts']
    if not email_config.get('enabled', False):
        return None

    return email_config


def send_email(config, subject, body):
    """Send email notification"""
    try:
        # Create message
        msg = MIMEMultipart('alternative')
        msg['From'] = config['from']
        msg['To'] = ', '.join(config['to'])
        msg['Subject'] = f"{config.get('subject_prefix', '[MikroTik Backup]')} {subject}"

        # Add timestamp to body
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        hostname = socket.gethostname()

        full_body = f"""
MikroTik Backup Alert
{'=' * 70}

Time: {timestamp}
Host: {hostname}

{body}

{'=' * 70}
This is an automated message from the MikroTik backup system.
"""

        # Attach body
        msg.attach(MIMEText(full_body, 'plain'))

        # Connect to SMTP server
        smtp_config = config['smtp']

        if smtp_config.get('use_tls', True):
            server = smtplib.SMTP(smtp_config['server'], smtp_config.get('port', 587))
            server.starttls()
        else:
            server = smtplib.SMTP(smtp_config['server'], smtp_config.get('port', 25))

        # Login if credentials provided
        if smtp_config.get('username') and smtp_config.get('password'):
            server.login(smtp_config['username'], smtp_config['password'])

        # Send email
        server.send_message(msg)
        server.quit()

        print(f"Email alert sent to: {', '.join(config['to'])}")
        return True

    except Exception as e:
        print(f"Failed to send email alert: {e}", file=sys.stderr)
        return False


def main():
    """Main function"""
    if len(sys.argv) < 3:
        print("Usage: send-alert.py <subject> <body>", file=sys.stderr)
        sys.exit(1)

    subject = sys.argv[1]
    body = sys.argv[2]

    # Load configuration
    config = load_config()

    if config is None:
        # Email alerts not configured or not enabled
        print("Email alerts not configured or disabled. Skipping notification.")
        sys.exit(0)

    # Send email
    if send_email(config, subject, body):
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == '__main__':
    main()
