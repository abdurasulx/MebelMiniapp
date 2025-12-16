from pathlib import Path
import environ

# Loyiha ildizini aniqlash
BASE_DIR = Path(__file__).resolve().parent.parent

# .env faylni aniq yo‘ldan o‘qish
environ.Env.read_env(BASE_DIR / '.env')  # To'g'ri!

env = environ.Env(
    DEBUG=(bool, False),
    # qo‘shimcha default qiymatlar
)

# Endi o‘qish
SECRET_KEY = env('DJANGO_SECRET_KEY')
DEBUG = env('DEBUG')
WEBAPP_BASE_URL = env('WEBAPP_BASE_URL')
ALLOWED_HOSTS = ['*','127.0.0.1']
TRUSTED_ORIGINS = ['*','localhost','127.0.0.1', env('WEBAPP_BASE_URL')]
CSRF_TRUSTED_ORIGINS = [env('WEBAPP_BASE_URL')]

# http://localhost:8000
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'main','widget_tweaks',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
]

ROOT_URLCONF = 'mebelweb.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'main' / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                'main.context_processors.cart_count',
            ],
        },
    },
]

DATABASES = {'default': env.db()}

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

WEBAPP_BASE_URL = env('WEBAPP_BASE_URL')

# Professional Logging Configuration
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {message}',
            'style': '{',
        },
        'simple': {
            'format': '{levelname} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': BASE_DIR / 'logs' / 'app.log',
            'formatter': 'verbose',
        },
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['console', 'file'],
            'level': 'INFO',
            'propagate': True,
        },
        'main': {  # Bizning app
            'handlers': ['console', 'file'],
            'level': 'INFO',
            'propagate': True,
        },
    },
}