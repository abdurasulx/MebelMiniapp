"""CLIP (OpenCLIP) + Qdrant orqali vizual qidiruv — techdocs'da tavsiya
etilgan V1 bosqichi: rasm -> embedding -> vektor bazasida qidiruv.

Model lokal diskka bir marta yuklab olinadi va process xotirasida keshlanadi
(yuklash ~80s, keyingi chaqiruvlar tez). Qdrant "embedded" rejimda —
alohida server kerak emas, ma'lumotlar `qdrant_data/` papkasida saqlanadi.

Katalog rasmlari mahsulot saqlanganda (`Product.save()`) avtomatik
indekslanadi — qidiruv vaqtida faqat foydalanuvchi yuborgan bitta rasm
embedding qilinadi (ko'p sonli mahsulot rasmini har safar qayta hisoblash
sekin bo'lardi)."""

import logging
from pathlib import Path

from django.conf import settings

logger = logging.getLogger(__name__)

EMBEDDING_DIM = 512
COLLECTION_NAME = "product_images"
_MODEL_NAME = "ViT-B-32-quickgelu"
_PRETRAINED = "openai"

_model = None
_preprocess = None
_qdrant = None
_collection_ready = False


def _load_model():
    global _model, _preprocess
    if _model is None:
        import open_clip

        model, _, preprocess = open_clip.create_model_and_transforms(
            _MODEL_NAME, pretrained=_PRETRAINED
        )
        model.eval()
        _model = model
        _preprocess = preprocess
    return _model, _preprocess


def compute_embedding(image_file):
    """Fayl-omonlik obyektidan (Django `ImageField` yoki oddiy fayl)
    normallashtirilgan 512-o'lchamli CLIP embedding hisoblaydi. Rasmni
    o'qib bo'lmasa `None` qaytaradi."""
    try:
        from PIL import Image

        if hasattr(image_file, "open"):
            image_file.open("rb")
        image_file.seek(0)
        img = Image.open(image_file).convert("RGB")
    except Exception:
        logger.exception("Rasmni ochib bo'lmadi (CLIP embedding)")
        return None
    finally:
        try:
            image_file.seek(0)
        except Exception:
            pass

    import torch

    model, preprocess = _load_model()
    tensor = preprocess(img).unsqueeze(0)
    with torch.no_grad():
        features = model.encode_image(tensor)
        features = features / features.norm(dim=-1, keepdim=True)
    return features[0].tolist()


def get_qdrant_client():
    global _qdrant
    if _qdrant is None:
        from qdrant_client import QdrantClient

        if getattr(settings, "TESTING", False):
            # Testlar disk-lokal `qdrant_data/` papkasini haqiqiy dev
            # serverga qarshi poyga qilib qo'ymasligi (fayl locki
            # to'qnashuvi) va har test run'da toza holatdan boshlashi uchun.
            _qdrant = QdrantClient(location=":memory:")
        else:
            path = Path(settings.BASE_DIR) / "qdrant_data"
            _qdrant = QdrantClient(path=str(path))
    return _qdrant


def _ensure_collection():
    global _collection_ready
    if _collection_ready:
        return
    from qdrant_client.models import Distance, VectorParams

    client = get_qdrant_client()
    existing = [c.name for c in client.get_collections().collections]
    if COLLECTION_NAME not in existing:
        client.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=VectorParams(size=EMBEDDING_DIM, distance=Distance.COSINE),
        )
    _collection_ready = True


def upsert_product_embedding(product):
    """Mahsulot rasmini embedding qilib Qdrant'ga saqlaydi (yoki rasm
    yo'q/o'chirilgan bo'lsa, mavjud yozuvni o'chiradi)."""
    if not product.image or product.is_deleted:
        delete_product_embedding(product.id)
        return
    embedding = compute_embedding(product.image)
    if embedding is None:
        return
    from qdrant_client.models import PointStruct

    _ensure_collection()
    client = get_qdrant_client()
    client.upsert(
        collection_name=COLLECTION_NAME,
        points=[
            PointStruct(
                id=str(product.id),
                vector=embedding,
                payload={
                    "category_id": str(product.category_id) if product.category_id else None,
                    "is_published": product.is_published,
                },
            )
        ],
    )


def delete_product_embedding(product_id):
    try:
        _ensure_collection()
        client = get_qdrant_client()
        client.delete(collection_name=COLLECTION_NAME, points_selector=[str(product_id)])
    except Exception:
        logger.exception("Qdrant'dan o'chirib bo'lmadi")


def search_similar(image_file, category_id=None, limit=20):
    """Berilgan rasmga eng o'xshash mahsulot ID'lari va o'xshashlik
    ballarini (0..1) qaytaradi, eng o'xshashidan boshlab."""
    embedding = compute_embedding(image_file)
    if embedding is None:
        return []

    _ensure_collection()
    client = get_qdrant_client()

    query_filter = None
    if category_id:
        from qdrant_client.models import FieldCondition, Filter, MatchValue

        query_filter = Filter(
            must=[FieldCondition(key="category_id", match=MatchValue(value=str(category_id)))]
        )

    result = client.query_points(
        collection_name=COLLECTION_NAME,
        query=embedding,
        query_filter=query_filter,
        limit=limit,
        with_payload=False,
    )
    return [(hit.id, hit.score) for hit in result.points]
