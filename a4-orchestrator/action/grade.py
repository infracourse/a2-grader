import json
import re
import sys
from typing import List

from jinja2 import Template
import yaml


class CustomEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, GradescopeTest):
            return obj.__dict__
        return super().default(obj)


class GradescopeTest:
    def __init__(
        self,
        name: str,
        score: int = 0,
        max_score: int = 10,
        failure: str = "Failed",
    ):
        self.name: str = name
        self.score: int = score
        self.max_score: int = max_score
        self.output: str = failure

    def mark_passed(self):
        self.output = "Pass"
        self.score = self.max_score


TESTS: List[GradescopeTest] = [
    GradescopeTest("Validate step 6 does not push built images"),
    GradescopeTest("Validate step 6 tags are not malformed"),
    GradescopeTest("Validate step 7 latest image is properly removed"),
    GradescopeTest("Validate step 8 does not push the built images"),
    GradescopeTest("Validate step 8 tags are not malformed"),
]


def finalize_grades() -> None:
    final_grade = sum([test.score for test in TESTS])
    print(
        json.dumps(
            {"actions_grade": final_grade, "results": TESTS},
            cls=CustomEncoder,
            indent=2,
        )
    )
    exit(0)


# Read YAML content from file
yaml_content = open(sys.argv[1], "r").read()

# Define hardcoded env variables
values = {
    "secrets": {"AWS_ACCOUNT_ID": "123456789123"},
    "env": {
        "AWS_REGION": "us-west-2",
        "ECR_REGISTRY": "123456789123.dkr.ecr.us-west-2.amazonaws.com",
        "ECR_REPOSITORY": "cs40",
    },
    "steps": {"timestamp": {"outputs": {"timestamp": "1709649832"}}},
}

if __name__ == "__main__":
    # Rendering the template
    template = Template(yaml_content)
    rendered_yaml = template.render(**values)

    # for the people who hardcoded stuff and didn't reference the environment variables
    rendered_yaml = re.sub(r"\b\d{12}\b", "123456789123", rendered_yaml).replace(
        "$", ""
    )

    steps = yaml.safe_load(rendered_yaml)["jobs"]["build-and-push"]["steps"]

    if steps[5]["with"]["push"] != False:
        TESTS[0].output = "Step 6 should not push the built images"
    else:
        TESTS[0].mark_passed()

    tags = re.split("\n|,", steps[5]["with"]["tags"])
    if len(tags) > 0 and tags[0][0] == "-":
        tags = [tag[1:] for tag in tags]
    tags = [tag.strip() for tag in tags if tag]

    if (
        len(tags) != 2
        or "123456789123.dkr.ecr.us-west-2.amazonaws.com/cs40:latest" not in tags
        or not "123456789123.dkr.ecr.us-west-2.amazonaws.com/cs40:1709649832" in tags
    ):
        TESTS[1].output = "Step 6 tags are malformed"
    else:
        TESTS[1].mark_passed()

    if (
        not steps[6]["run"].strip().startswith("aws ecr batch-delete-image")
        or "imageTag=latest" not in steps[6]["run"]
    ):
        TESTS[2].output = "Step 7 does not remove the latest image properly"
    else:
        TESTS[2].mark_passed()

    if "push" in steps[7]["with"] and steps[7]["with"]["push"] != True:
        TESTS[3].output = "Step 8 should push the built images"
    else:
        TESTS[3].mark_passed()

    tags = re.split("\n|,", steps[7]["with"]["tags"])
    if len(tags) > 0 and tags[0][0] == "-":
        tags = [tag[1:] for tag in tags]
    tags = [tag.strip() for tag in tags if tag]

    if (
        len(tags) != 2
        or "123456789123.dkr.ecr.us-west-2.amazonaws.com/cs40:latest" not in tags
        or not "123456789123.dkr.ecr.us-west-2.amazonaws.com/cs40:1709649832" in tags
    ):
        TESTS[4].output = "Step 8 tags are malformed"
    else:
        TESTS[4].mark_passed()

    finalize_grades()
