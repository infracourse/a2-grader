import json
import random
import requests
import string
import time
from typing import List

import cv2
import pdqhash
from PIL import Image
import numpy as np
from selenium import webdriver
from selenium.webdriver.chrome.options import Options


# fmt: off
EXPECTED_HASH = [0,1,1,0,0,1,0,0,1,1,0,0,1,1,0,0,0,1,1,0,0,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,0,0,1,1,0,1,1,0,0,1,1,0,0,1,1,1,0,0,1,1,0,1,1,0,0,1,1,0,0,1,1,0,1,1,0,0,1,0,0,1,1,0,1,1,0,0,1,0,1,1,0,0,1,0,0,1,1,0,0,1,1,0,0,0,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,0,0,1,1,1,1,0,0,1,1,0,0,1,1,0,1,0,0,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,1,0,0,1,1,0,0,1,0,1,1,1,0,0,0,1,1,0,0,1,1,0,0,1,0,1,1,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,1,0,0,1,1,0,0,1,1,0,1,1,0,0,1,1,1,0,0,1,1,0,0,1,1,0,0,0,1,1,0,0,0,1,1,0,0,1,1,0,0,1]
# fmt: on

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
    GradescopeTest("Validate front page loads", max_score=20),
    GradescopeTest("Create first account"),
    GradescopeTest("Create second account"),
    GradescopeTest("Login to first account"),
    GradescopeTest("Login to second account"),
    GradescopeTest("Create public post from first account"),
    GradescopeTest("Create private post from first account"),
    GradescopeTest("Check for public post from first account"),
    GradescopeTest("Check for private post from first account"),
    GradescopeTest("Check for public post from second account"),
    GradescopeTest("Check private post isn't accessible from second account"),
]


def _generate_random_string(length: int = 12) -> str:
    characters: str = string.ascii_letters + string.digits
    return "".join(random.choice(characters) for _ in range(length))


def validate_frontpage():
    SCREENSHOT_FILE_PATH = "/tmp/screenshot.png"

    chrome_options = Options()
    chrome_options.add_argument("window-size=1920x1080")
    chrome_options.add_argument("--headless")
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("start-maximized")
    chrome_options.add_argument("disable-infobars")
    chrome_options.add_argument("--disable-extensions")

    driver = webdriver.Chrome(options=chrome_options)

    driver.get(PREFIX)

    # race condition, allow everything to load, 10 is excessive but rather safe than sorry
    time.sleep(10)

    driver.save_screenshot(SCREENSHOT_FILE_PATH)

    image = cv2.imread(SCREENSHOT_FILE_PATH)
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    hash_vector, quality = pdqhash.compute(image)

    difference = 256 - np.sum(hash_vector == EXPECTED_HASH)
    if difference > 16:
        raise Exception("Bad hash on front page")


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


# returns file path of image, will be somewhere in /tmp
# image is a 1000x1000 image of a random RGB color
def generate_random_image() -> str:
    color = (random.randint(0, 255), random.randint(0, 255), random.randint(0, 255))
    image = Image.new("RGB", (1000, 1000), color)
    filepath = f"/tmp/{_generate_random_string()}.png"
    image.save(filepath)
    return filepath


def upload_image(url, file_path, fields):
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


def check_image(token, image_id):
    url = MEDIA_URL.format(PREFIX, image_id)
    response = requests.get(url, headers=_add_token_to_headers(token))
    if response.status_code != 200:
        raise Exception(f"Failed to get image link from backend: {response.text}")

    s3_uri = response.json()["uri"]
    if response.status_code != 200:
        raise Exception(f"Failed to get image from Cloudfront: {response.text}")


def check_image_inaccessible(token, image_id):
    url = MEDIA_URL.format(PREFIX, image_id)
    response = requests.get(url, headers=_add_token_to_headers(token))
    if response.headers["content-type"] == "application/json":
        raise Exception(
            f"Expected to not get a JSON response, but got: {response.text}"
        )


def finalize_grades():
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
    # validate front page loads
    try:
        validate_frontpage()
        TESTS[0].mark_passed()
    except Exception as e:
        TESTS[0].output = str(e)

    # create account 1
    try:
        account1: LoginData = create_account()
        TESTS[1].mark_passed()
    except Exception as e:
        TESTS[1].output = str(e)
        finalize_grades()

    # login to account 1
    try:
        token1: str = login(account1)
        TESTS[2].mark_passed()
    except Exception as e:
        TESTS[2].output = str(e)
        finalize_grades()

    # create account 2
    try:
        account2: LoginData = create_account()
        TESTS[3].mark_passed()
    except Exception as e:
        TESTS[3].output = str(e)
        finalize_grades()

    # login to account 2
    try:
        token2: str = login(account2)
        TESTS[4].mark_passed()
    except Exception as e:
        TESTS[4].output = str(e)
        finalize_grades()

    # make public post from account 1
    try:
        json_response_public = generate_upload_url(token1, "public")
        filepath = generate_random_image()
        upload_image(
            json_response_public["url"], filepath, json_response_public["fields"]
        )
        TESTS[5].mark_passed()
    except Exception as e:
        TESTS[5].output = str(e)
        finalize_grades()

    # make private post from account 1
    try:
        json_response_private = generate_upload_url(token1, "private")
        filepath = generate_random_image()
        upload_image(
            json_response_private["url"], filepath, json_response_private["fields"]
        )
        TESTS[6].mark_passed()
    except Exception as e:
        TESTS[6].output = str(e)
        finalize_grades()

    # check for public post from account 1
    try:
        check_image(token1, json_response_public["id"])
        TESTS[7].mark_passed()
    except Exception as e:
        TESTS[7].output = str(e)
        finalize_grades()

    # check for private post from account 1
    try:
        check_image(token1, json_response_private["id"])
        TESTS[8].mark_passed()
    except Exception as e:
        TESTS[8].output = str(e)
        finalize_grades()

    # check for public post from account 2
    try:
        check_image(token2, json_response_public["id"])
        TESTS[9].mark_passed()
    except Exception as e:
        TESTS[9].output = str(e)
        finalize_grades()

    # check for private post from account 2
    try:
        check_image_inaccessible(token2, json_response_private["id"])
        TESTS[10].mark_passed()
    except Exception as e:
        TESTS[10].output = str(e)
        finalize_grades()

    finalize_grades()


main()
