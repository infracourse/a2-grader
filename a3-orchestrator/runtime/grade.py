from io import BytesIO
import json
import os
import random
import requests
import string
import time
from typing import Dict, List, Tuple

from PIL import Image, ImageDraw

SUNET = ""

with open("/autograder/submission/SUNET") as sunet:
    SUNET = sunet.read().strip().rstrip()

# URL of the API endpoint
PREFIX = f"https://yoctogram.{SUNET}.infracourse.cloud"
REGISTER_URL: str = f"{PREFIX}/api/v1/auth/register/"
LOGIN_URL: str = f"{PREFIX}/api/v1/auth/login/"
UPLOAD_URL: str = "{}/api/v1/images/upload/{}/generate"
MEDIA_URL: str = "{}/api/v1/images/media/{}"

# Headers
JSON_HEADERS: dict[str, str] = {
    "Content-Type": "application/json",
    "Origin": PREFIX,
    "Connection": "keep-alive",
    "Referer": "f{PREFIX}/",
}
BLOB_HEADERS: dict[str, str] = {
    "Origin": PREFIX,
    "Connection": "keep-alive",
    "Referer": "f{PREFIX}/",
}


class LoginData:
    def __init__(self, username: str, password: str, email: str):
        self.username: str = username
        self.password: str = password
        self.email: str = email

    def to_json(self) -> str:
        return json.dumps(self.__dict__)


class GradescopeTest:
    def __init__(
        self,
        name: str,
        score: int = 0,
        max_score: int = 4,
        failure: str = "Unable to execute test due to previous failures",
    ):
        self.name: str = name
        self.score: int = score
        self.max_score: int = max_score
        self.output: str = failure

    def mark_passed(self):
        self.output = "Pass"
        self.score = self.max_score


class CustomEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, GradescopeTest) or isinstance(obj, LoginData):
            return obj.__dict__
        return super().default(obj)


TESTS: List[GradescopeTest] = [
    GradescopeTest("Validate create first account still works", max_score=2),
    GradescopeTest("Validate login to first account still works", max_score=2),
    GradescopeTest("Validate create public post from first account still works"),
    GradescopeTest("Validate check for public post from first account still works"),
    GradescopeTest(
        "Validate retrieve image for public post from first account still works"
    ),
    GradescopeTest(
        "Check retrieved public post from first account is compressed", max_score=20
    ),
]


def _generate_random_string(length: int = 12) -> str:
    characters: str = string.ascii_letters + string.digits
    return "".join(random.choice(characters) for _ in range(length))


def create_account() -> LoginData:
    data: LoginData = LoginData(
        _generate_random_string(),
        _generate_random_string(),
        f"{_generate_random_string()}@infracourse.cloud",
    )

    response = requests.post(REGISTER_URL, json=data.__dict__, headers=JSON_HEADERS)

    # Check the status code of the response
    try:
        # Parse the response text as JSON
        json_response = response.json()

        # Check if the "success" field is true
        if (
            response.status_code >= 200
            and response.status_code < 300
            and "success" in json_response
            and json_response["success"] == True
        ):
            return data
        elif "detail" in json_response:
            raise Exception(
                f"Account registration failed: {json_response['detail']}; Status code {response.status_code}"
            )
        else:
            raise Exception(
                f"Account registration failed: unknown error; Status code: {response.status_code}"
            )
    except ValueError:
        raise Exception(
            f"Account registration failed: Error parsing JSON in the response; Status code: {response.status_code}"
        )


def login(data: LoginData):
    response = requests.post(LOGIN_URL, json=data.__dict__, headers=JSON_HEADERS)

    # Check the status code of the response
    try:
        # Parse the response text as JSON
        json_response = response.json()

        if (
            response.status_code >= 200
            and response.status_code < 300
            and "access_token" in json_response
        ):
            return json_response["access_token"]
        elif "detail" in json_response:
            raise Exception(
                f"Login failed: {json_response['detail']}; Status code {response.status_code}"
            )
        else:
            raise Exception(
                f"Login failed: unknown error; Status code: {response.status_code}"
            )
    except ValueError:
        raise Exception(
            f"Login failed: Error parsing JSON in the response; Status code: {response.status_code}"
        )


def _add_token_to_headers(token):
    headers_with_token = JSON_HEADERS.copy()
    headers_with_token["Authorization"] = f"Bearer {token}"
    return headers_with_token


def generate_upload_url(token: str, privacy: str):
    # Assuming privacy is part of the URL path
    url = UPLOAD_URL.format(PREFIX, privacy)

    try:
        # Make the request to generate the upload URL
        response = requests.post(url, headers=_add_token_to_headers(token))
        json_response = response.json()
        if (
            response.status_code >= 200
            and response.status_code < 300
            and "success" in json_response
            and json_response["success"] == True
        ):
            return json_response
        elif "detail" in json_response:
            raise Exception(
                f"Login failed: {json_response['detail']}; Status code {response.status_code}"
            )
        else:
            raise Exception(
                f"Login failed: unknown error; Status code: {response.status_code}"
            )
    except ValueError:
        raise Exception(
            f"Account registration failed: Error parsing JSON in the response; Status code: {response.status_code}"
        )


def generate_image_with_polygons(
    width: int = 500, height: int = 500, num_polygons: int = 10
) -> Tuple[str, int]:
    """Create a new image with random polygons."""
    # Create a new image with white background
    img = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(img)

    for _ in range(num_polygons):
        # Generate some random points
        points = [
            (random.randint(0, width), random.randint(0, height))
            for _ in range(random.randint(3, 10))
        ]

        # Generate a random color
        color = (random.randint(0, 255), random.randint(0, 255), random.randint(0, 255))

        # Draw the polygon on the image
        draw.polygon(points, fill=color)

    filepath = f"/tmp/{_generate_random_string()}.jpg"
    img.save(filepath)
    return filepath, os.path.getsize(filepath)


def upload_image(url: str, file_path: str, fields: Dict[str, str]) -> None:
    # Load the file
    with open(file_path, "rb") as file:
        files = {}
        for key, value in fields.items():
            files[key] = value

        files["file"] = (file.name, file, "image/png")

        # Make the request to upload the image
        response = requests.post(url, files=files)
        # Check if the request was successful
        if response.status_code not in [200, 204]:
            # Handle failure here
            raise Exception("Image upload failed:", response.text)


def check_image(token: str, image_id: str) -> str:
    url = MEDIA_URL.format(PREFIX, image_id)
    response = requests.get(url, headers=_add_token_to_headers(token))
    if response.status_code != 200:
        raise Exception(f"Failed to get image link from backend: {response.text}")

    cloudfront_uri = response.json()["uri"]
    if response.status_code != 200:
        raise Exception(f"Failed to get image from Cloudfront: {response.text}")

    return cloudfront_uri


def check_download_image(cloudfront_uri: str) -> bytes:
    response = requests.get(cloudfront_uri)
    if response.status_code != 200:
        raise Exception(f"Failed to download image from Cloudfront: {response.text}")

    return response.content


def finalize_grades() -> None:
    final_grade = sum([test.score for test in TESTS])
    print(
        json.dumps(
            {"runtime_grade": final_grade, "results": TESTS},
            cls=CustomEncoder,
            indent=2,
        )
    )
    exit(0)


def main():
    # create account
    try:
        account: LoginData = create_account()
        TESTS[0].mark_passed()
    except Exception as e:
        TESTS[0].output = str(e)
        finalize_grades()

    # login to account
    try:
        token: str = login(account)
        TESTS[1].mark_passed()
    except Exception as e:
        TESTS[1].output = str(e)
        finalize_grades()

    # make public post from account
    try:
        json_response_public = generate_upload_url(token, "public")
        filepath, size = generate_image_with_polygons()
        upload_image(
            json_response_public["url"], filepath, json_response_public["fields"]
        )
        TESTS[2].mark_passed()
    except Exception as e:
        TESTS[2].output = str(e)
        finalize_grades()

    # wait for lambda to run to compress image
    time.sleep(10)

    # check for public post from account 1
    try:
        cloudfront_uri = check_image(token, json_response_public["id"])
        TESTS[3].mark_passed()
    except Exception as e:
        TESTS[3].output = str(e)
        finalize_grades()

    # check media download works
    try:
        content = check_download_image(cloudfront_uri)
        with Image.open(BytesIO(content)) as image:
            image.verify()
        TESTS[4].mark_passed()
    except Exception as e:
        TESTS[4].output = str(e)
        finalize_grades()

    # check media download yields compressed image
    try:
        if len(content) <= 0.75 * size:
            TESTS[5].mark_passed()
        else:
            TESTS[5].output = (
                f"Image was not compressed: {len(content)} > {0.75 * size}"
            )
    except Exception as e:
        TESTS[4].output = str(e)
        finalize_grades()

    finalize_grades()


main()
