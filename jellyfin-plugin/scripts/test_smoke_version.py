"""Check the smoke test's version gate without starting Docker."""
import ast
from pathlib import Path
import re
import unittest


class SmokeVersionTest(unittest.TestCase):
    def test_supported_patch_versions(self):
        tree = ast.parse(Path(__file__).with_name('smoke_test.py').read_text())
        gate = next(node for node in ast.walk(tree)
                    if isinstance(node, ast.Assert) and "info['Version']" in ast.unparse(node.test))
        expression = compile(ast.Expression(gate.test), '<version-gate>', 'eval')
        for version in ('12.0.0', '12.0.1', '12.0.123'):
            self.assertTrue(eval(expression, {'re': re, 'info': {'Version': version}}), version)
        for version in ('10.11.12', '12.1.0', '13.0.0', '12.0.x', '12.0.1-preview'):
            self.assertFalse(eval(expression, {'re': re, 'info': {'Version': version}}), version)


if __name__ == '__main__':
    unittest.main()
