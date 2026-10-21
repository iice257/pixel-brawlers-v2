extends GutTest
## Stage 1 camera: never shows past the deck, and is pinned at the centre when the view is wider than the deck.

func test_camera_clamp_keeps_view_inside_deck() -> void:
	for dist in [10.2, 12.0, 14.0]:
		var half_view: float = dist * tan(deg_to_rad(AirshipDeck.FOV * 0.5)) * AirshipDeck.ASPECT
		var x := AirshipDeck.clamp_camera_x(99.0, dist)
		assert_true(x + half_view <= AirshipDeck.HALF_W + AirshipDeck.EDGE_MARGIN + 0.001 or x == 0.0, "right edge at dist %s" % dist)
		assert_eq(AirshipDeck.clamp_camera_x(-99.0, dist), -x, "symmetric at dist %s" % dist)

func test_camera_clamp_passes_centre_through() -> void:
	assert_eq(AirshipDeck.clamp_camera_x(0.0, 10.2), 0.0)

func test_wider_view_means_tighter_limit() -> void:
	assert_true(AirshipDeck.camera_limit(14.0) <= AirshipDeck.camera_limit(10.2))
