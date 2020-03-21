import unittest
import requests
import time

eventUrl = "http://localhost:8080/sky/event/{}/1/{}/{}{}"
cloudUrl = "http://localhost:8080/sky/cloud/{}/{}/{}"
root_eci = "KFrnQ857KBkmN2TAyneytQ"

class MyPicoTest(unittest.TestCase):

    def test_creating_and_deleting(self):
        response = requests.get(eventUrl.format(root_eci, "sensor", "new_sensor", "?sensor_id=1"))
        pico_create_response = response.json()["directives"][0]["options"]["pico"]
        assert pico_create_response["name"] == "Sensor 1 Pico"
        assert pico_create_response["parent_eci"]
        assert pico_create_response["eci"]
        name_to_delete = pico_create_response["name"]
        # time.sleep(10)
        response2 = requests.get(eventUrl.format(root_eci, "sensor", "new_sensor", "?sensor_id=1"))
        print(response2.json())
        assert response2.json()["directives"][0]["options"]["sensor already created"] == "1"
        delete_response = requests.get(eventUrl.format(root_eci, "sensor", "unneeded_sensor", "?name={}".format(name_to_delete).replace(" ", "%20")))

        assert delete_response.json()["directives"][0]["options"]["ids"][0] == pico_create_response["id"]
        print(delete_response)

    def test_responds_to_new_threshold(self):
        response = requests.get(eventUrl.format(root_eci, "sensor", "new_sensor", "?sensor_id=1")).json()["directives"][0]["options"]["pico"]
        requests.post(eventUrl.format(response["eci"], "get", "heartbeat", ""), json = {"genericThing": {"data": {"temperature": [{"temperatureF": 65.8}]}}}).json()
        temperatures = requests.get(cloudUrl.format(root_eci, "manage_sensors", "get_all_temperatures")).json()
        assert len(temperatures["Sensor 1 Pico"]) == 1
        assert temperatures["Sensor 1 Pico"][0]["temp"] == 65.8
        requests.get(eventUrl.format(root_eci, "sensor", "unneeded_sensor", "?name={}".format(response["name"]).replace(" ", "%20")))

    # @unittest.skip
    def test_delete(self):
        response = requests.get(eventUrl.format(root_eci, "sensor", "new_sensor", "?sensor_id=1")).json()["directives"][0]["options"]["pico"]
        response2 = requests.get(eventUrl.format(root_eci, "sensor", "new_sensor", "?sensor_id=2")).json()["directives"][0]["options"]["pico"]

        requests.get(eventUrl.format(root_eci, "sensor", "unneeded_sensor", "?name={}".format("Sensor 1 Pico".replace(" ", "%20"))))
        requests.get(eventUrl.format(root_eci, "sensor", "unneeded_sensor", "?name={}".format("Sensor 2 Pico".replace(" ", "%20"))))


    def test_sensor_profile_being_set(self):
        response = requests.get(eventUrl.format(root_eci, "sensor", "new_sensor", "?sensor_id=1")).json()["directives"][0]["options"]["pico"]
        response2 = requests.get(eventUrl.format(root_eci, "sensor", "new_sensor", "?sensor_id=2")).json()["directives"][0]["options"]["pico"]

        profile_info = requests.get(cloudUrl.format(response["eci"], "sensor_profile", "profile")).json()
        profile_info2 = requests.get(cloudUrl.format(response2["eci"], "sensor_profile", "profile")).json()
        assert profile_info["location"] == "location"
        assert profile_info["name"] == "Sensor 1 Pico"
        assert profile_info["notification_number"] == "+8016366490"
        assert profile_info["threshold_temperature"] == 75.4
        assert profile_info2["name"] == "Sensor 2 Pico"
        print(profile_info2)
        print(profile_info)

        delete_response = requests.get(eventUrl.format(root_eci, "sensor", "unneeded_sensor", "?name={}".format(response["name"]).replace(" ", "%20")))
        delete_response2 = requests.get(eventUrl.format(root_eci, "sensor", "unneeded_sensor", "?name={}".format(response2["name"]).replace(" ", "%20")))

    def test_7(self):
        response = requests.get(eventUrl.format(root_eci, "sensor", "new_sensor", "?sensor_id=1")).json()["directives"][0]["options"]["pico"]
        response2 = requests.get(eventUrl.format(root_eci, "sensor", "new_sensor", "?sensor_id=2")).json()["directives"][0]["options"]["pico"]

        profile_info = requests.get(cloudUrl.format(response["eci"], "sensor_profile", "profile")).json()
        profile_info2 = requests.get(cloudUrl.format(response2["eci"], "sensor_profile", "profile")).json()
        # assert profile_info["location"] == "location"
        # assert profile_info["name"] == "Sensor 1 Pico"
        # assert profile_info["notification_number"] == "+8016366490"
        # assert profile_info["threshold_temperature"] == 75.4
        # assert profile_info2["name"] == "Sensor 2 Pico"
        print(profile_info2)
        print(profile_info)

        temperatures_from_manager = requests.get(cloudUrl.format(root_eci, "manage_sensors", "get_all_temperatures")).json()
        print(temperatures_from_manager)

        delete_response = requests.get(eventUrl.format(root_eci, "sensor", "unneeded_sensor", "?name={}".format(response["name"]).replace(" ", "%20")))
        delete_response2 = requests.get(eventUrl.format(root_eci, "sensor", "unneeded_sensor", "?name={}".format(response2["name"]).replace(" ", "%20")))

    def test_8(self):
        try:
            response = requests.get(eventUrl.format(root_eci, "sensor", "new_sensor", "?sensor_id=1")).json()["directives"][0]["options"]["pico"]
            response2 = requests.get(eventUrl.format(root_eci, "sensor", "new_sensor", "?sensor_id=2")).json()["directives"][0]["options"]["pico"]

            requests.post(eventUrl.format(response["eci"], "get", "heartbeat", ""), json = {"genericThing": {"data": {"temperature": [{"temperatureF": 65.8}]}}}).json()
            requests.post(eventUrl.format(response2["eci"], "get", "heartbeat", ""), json = {"genericThing": {"data": {"temperature": [{"temperatureF": 65.8}]}}}).json()
            temperatures_from_manager = requests.get(cloudUrl.format(root_eci, "manage_sensors", "get_all_temperatures")).json()
            print(temperatures_from_manager)


            startReport = requests.get(eventUrl.format(root_eci, "report", "start", "")).json()

            print(requests.get(cloudUrl.format(root_eci, "manage_sensors", "reports")).json())

        finally:
            requests.get(eventUrl.format(root_eci, "sensor", "unneeded_sensor", "?name={}".format(response["name"]).replace(" ", "%20")))
            requests.get(eventUrl.format(root_eci, "sensor", "unneeded_sensor", "?name={}".format(response2["name"]).replace(" ", "%20")))

