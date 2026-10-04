import unittest
from pathlib import Path
from scripts.check_workflow_protocols import check_workflow_protocols


class WorkflowProtocolTest(unittest.TestCase):
    def test_workflow_packets_declared(self):
        report = check_workflow_protocols(Path(__file__).resolve().parents[1])
        self.assertEqual(report["errors"], [])
        self.assertEqual(report["protocol_count"], 33)



if __name__ == "__main__":
    unittest.main()
