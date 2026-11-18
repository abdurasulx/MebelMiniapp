"""Do not infer camera viewpoints from upload order."""
ROLES = ("front", "back", "left", "right")


def image_roles(count, raw):
    if not 1 <= count <= len(ROLES):
        raise ValueError("1 tadan 4 tagacha rasm yuboring")
    if count == 1:
        return ["front"]
    roles = [part.strip() for part in raw.split(",")]
    if len(roles) != count or any(role not in ROLES for role in roles):
        raise ValueError("Har rasm uchun rakursni aniq tanlang: old, orqa, chap yoki o‘ng")
    if len(set(roles)) != count or "front" not in roles:
        raise ValueError("Har rakurs bir marta tanlanadi; bitta old rasm majburiy")
    return roles
