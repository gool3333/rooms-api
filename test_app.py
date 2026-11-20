import unittest

import app


class BookingTests(unittest.TestCase):
    def setUp(self):
        app.BOOKINGS.clear()

    def test_valid_booking(self):
        self.assertIsNone(app.validate_booking({"room": "vega", "hour": 10, "who": "Ivanov"}))

    def test_unknown_room(self):
        self.assertEqual(app.validate_booking({"room": "mars", "hour": 10, "who": "Ivanov"}), "нет такой переговорной")

    def test_hour_outside_working_day(self):
        self.assertIn("час должен быть", app.validate_booking({"room": "vega", "hour": 20, "who": "Ivanov"}))

    def test_empty_name(self):
        self.assertIsNotNone(app.validate_booking({"room": "vega", "hour": 10, "who": "  "}))

    def test_double_booking(self):
        app.add_booking({"room": "lyra", "hour": 12, "who": "Ivanov"})
        self.assertEqual(app.validate_booking({"room": "lyra", "hour": 12, "who": "Petrov"}), "это время уже занято")


if __name__ == "__main__":
    unittest.main()
