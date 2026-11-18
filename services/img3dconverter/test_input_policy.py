import pytest
from input_policy import image_roles


def test_single_image_remains_compatible_with_scanner():
    assert image_roles(1, "") == ["front"]


def test_explicit_order_is_preserved():
    assert image_roles(3, "back, front,right") == ["back", "front", "right"]


@pytest.mark.parametrize("count,roles", [
    (3, ""), (3, "front"), (3, "front,,back"),
    (3, "front,left,left"), (2, "back,right"),
    (2, "front,diagonal"), (0, ""), (5, "front,back,left,right,top"),
])
def test_invalid_or_ambiguous_views_are_rejected(count, roles):
    with pytest.raises(ValueError):
        image_roles(count, roles)
