"""PowerShell execution utilities"""

import subprocess
from pathlib import Path
from typing import Optional, Any
import json
import base64
import gzip

from .config import AppConfig


class PowerShellError(Exception):
    """Custom exception for PowerShell execution errors"""
    pass


class PowerShellTimeoutError(PowerShellError):
    """Exception for PowerShell execution timeouts"""
    pass


class PowerShellRunner:
    """Centralized PowerShell script execution"""
    
    def __init__(self, script_name: str, timeout: Optional[int] = None):
        """Initialize PowerShell runner
        
        Args:
            script_name: Name of the PowerShell script to run
            timeout: Timeout in seconds (uses default if not specified)
        """
        self.script_path = AppConfig.get_script_path(script_name)
        self.timeout = timeout or AppConfig.TIMEOUT_DEFAULT
        
    def run(
        self,
        args: Optional[dict[str, str]] = None,
        decode_base64: bool = False,
        decompress_gzip: bool = False
    ) -> str:
        """Execute PowerShell script with arguments
        
        Args:
            args: Dictionary of argument names and values
            decode_base64: Whether to decode base64 output
            decompress_gzip: Whether to decompress gzip output
            
        Returns:
            Script output as string
            
        Raises:
            PowerShellTimeoutError: If execution times out
            PowerShellError: If execution fails
        """
        command = self._build_command(args)
        
        try:
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                encoding='utf-8',
                timeout=self.timeout,
                check=False  # We handle errors manually
            )
            
            # Check for errors
            if result.returncode != 0:
                if result.returncode == 2 and 'timeout' in result.stdout.lower():
                    raise PowerShellTimeoutError(
                        f"PowerShell script timed out after {self.timeout} seconds"
                    )
                raise PowerShellError(
                    f"PowerShell script failed with code {result.returncode}: {result.stderr}"
                )
            
            output = result.stdout.strip()
            
            # Post-process output if needed
            if decode_base64:
                output = self._decode_base64(output)
            if decompress_gzip:
                output = self._decompress_gzip(output)
                
            return output
            
        except subprocess.TimeoutExpired:
            raise PowerShellTimeoutError(
                f"PowerShell script execution timed out after {self.timeout} seconds"
            )
        except Exception as e:
            if isinstance(e, (PowerShellError, PowerShellTimeoutError)):
                raise
            raise PowerShellError(f"Unexpected error executing PowerShell script: {str(e)}")
    
    def run_json(
        self,
        args: Optional[dict[str, str]] = None,
        decode_base64: bool = False,
        decompress_gzip: bool = False
    ) -> Any:
        """Execute PowerShell script and parse JSON output
        
        Args:
            args: Dictionary of argument names and values
            decode_base64: Whether to decode base64 output before parsing
            decompress_gzip: Whether to decompress gzip output before parsing
            
        Returns:
            Parsed JSON object
            
        Raises:
            PowerShellError: If execution or JSON parsing fails
        """
        output = self.run(args, decode_base64, decompress_gzip)
        try:
            return json.loads(output)
        except json.JSONDecodeError as e:
            raise PowerShellError(f"Failed to parse JSON output: {str(e)}")
    
    def _build_command(self, args: Optional[dict[str, str]]) -> list[str]:
        """Build PowerShell command with arguments
        
        Args:
            args: Dictionary of argument names and values
            
        Returns:
            Command as list of strings
        """
        # Normalize path for Windows
        script_path_str = str(self.script_path).replace('\\', '\\\\')
        
        command = [
            'pwsh',
            '-NoProfile',
            '-File', script_path_str
        ]
        
        # Add arguments
        if args:
            for key, value in args.items():
                command.extend([f'-{key}', str(value)])
        
        return command
    
    @staticmethod
    def _decode_base64(data: str) -> str:
        """Decode base64 string
        
        Args:
            data: Base64 encoded string
            
        Returns:
            Decoded string
        """
        return base64.b64decode(data).decode('utf-8')
    
    @staticmethod
    def _decompress_gzip(data: str) -> str:
        """Decompress gzip data
        
        Args:
            data: Gzip compressed base64 string
            
        Returns:
            Decompressed string
        """
        compressed = base64.b64decode(data)
        return gzip.decompress(compressed).decode('utf-8')
