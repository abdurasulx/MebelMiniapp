"""CPU foreground extraction; preserve all pieces of a furniture set."""
import gc
import os
from rembg import new_session, remove


class ForegroundExtractor:
    def __init__(self):
        self.session = None
        self.model = None

    def release(self):
        self.session = None
        self.model = None
        gc.collect()

    def __call__(self, image, model="birefnet-general-lite"):
        if model not in ("u2net", "birefnet-general-lite"):
            raise ValueError("Unsupported foreground model")
        if self.session is None or self.model != model:
            os.environ.setdefault("OMP_NUM_THREADS", "4")
            session = new_session(model, providers=["CPUExecutionProvider"])
            self.session, self.model = session, model
        output = remove(image.convert("RGB"), session=self.session,
                        bgcolor=[255, 255, 255, 0]).convert("RGBA")
        # Tiny nearly transparent background pixels must not determine the
        # neural model's recentering box. Do not select only one component.
        alpha = output.getchannel("A").point(lambda value: 0 if value < 8 else value)
        if alpha.getbbox() is None:
            raise ValueError("Rasmdan mebel ajratilmadi")
        output.putalpha(alpha)
        return output
