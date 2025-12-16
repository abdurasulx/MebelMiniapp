import asyncio
import os
import json
from aiogram import Bot, Dispatcher, types, F
from aiogram.filters import CommandStart
from aiogram.types import WebAppInfo, InlineKeyboardMarkup, InlineKeyboardButton
from dotenv import load_dotenv

# Load environment variables
load_dotenv(dotenv_path='../mebelweb/.env')

# Get configuration from .env
BOT_TOKEN = os.getenv('TG_BOT_TOKEN')
WEBAPP_URL = os.getenv('WEBAPP_BASE_URL')

# Initialize bot and dispatcher
bot = Bot(token=BOT_TOKEN)
dp = Dispatcher()

# Multi-language texts
TEXTS = {
    'uz': {
        'welcome': "Mebel do'koniga xush kelibsiz! 🛋️\n\nIlovamizdan foydalanish uchun quyidagi tugmani bosing:",
        'button': "📱 Ilovaga kirish"
    },
    'ru': {
        'welcome': "Добро пожаловать в мебельный магазин! 🛋️\n\nНажмите кнопку ниже, чтобы использовать приложение:",
        'button': "📱 Войти в приложение"
    },
    'en': {
        'welcome': "Welcome to the furniture store! 🛋️\n\nPress the button below to use the app:",
        'button': "📱 Enter the app"
    }
}


def get_user_language(user: types.User) -> str:
    """
    Determine user's language based on their Telegram language code
    """
    lang_code = user.language_code
    
    if lang_code and lang_code.startswith('uz'):
        return 'uz'
    elif lang_code and lang_code.startswith('ru'):
        return 'ru'
    else:
        return 'en'


def get_webapp_keyboard(language: str, message: types.Message) -> InlineKeyboardMarkup:
    """
    Create inline keyboard with web app button
    """
    keyboard = InlineKeyboardMarkup(
        inline_keyboard=[
            [
                InlineKeyboardButton(
                    text=TEXTS[language]['button'],
                    web_app=WebAppInfo(
                        url=f"{WEBAPP_URL}/login/?tg_id={message.from_user.id}&next=/"
                    )
                )
            ]
        ]
    )
    print(f"WebApp URL: {WEBAPP_URL}/login/?tg_id={message.from_user.id}&next=/")
    return keyboard


@dp.message(CommandStart())
async def cmd_start(message: types.Message):
    """
    Handle /start command
    """
    # Determine user's language
    user_lang = get_user_language(message.from_user)
    
    # Get welcome text and keyboard
    welcome_text = TEXTS[user_lang]['welcome']
    keyboard = get_webapp_keyboard(user_lang, message)
    
    # Send message with web app button
    await message.answer(
        text=welcome_text,
        reply_markup=keyboard
    )
    print(f"✅ /start command handled for user {message.from_user.id}")


@dp.message(F.web_app_data)
async def handle_web_app_data(message: types.Message):
    """
    Handle data from web app (orders) - FIXED VERSION
    """
    print(f"\n{'='*50}")
    print(f"📨 Received web_app_data from user {message.from_user.id}")
    print(f"{'='*50}")
    
    try:
        # Parse data from web app
        data = json.loads(message.web_app_data.data)
        print(f"📦 Parsed data: {json.dumps(data, indent=2, ensure_ascii=False)}")
        
        if data.get('action') == 'place_order':
            items = data.get('items', [])
            
            if not items:
                await message.answer("❌ Buyurtma bo'sh!")
                print("❌ Order is empty")
                return
            
            print(f"✅ Processing order with {len(items)} items")
            
            # Create order confirmation message
            order_text = "✅ *Buyurtmangiz qabul qilindi!*\n\n"
            order_text += "📦 *Buyurtma tarkibi:*\n"
            
            total = 0
            for i, item in enumerate(items, 1):
                product_name = item.get('product_name', 'Noma\'lum')
                material = item.get('material', '')
                quantity = item.get('quantity', 1)
                price = item.get('price', 0)
                width = item.get('width', 0)
                height = item.get('height', 0)
                depth = item.get('depth', 0)
                
                item_total = price * quantity
                total += item_total
                
                order_text += f"\n{i}. *{product_name}*\n"
                order_text += f"   Material: {material}\n"
                order_text += f"   O'lchami: {width}×{height}×{depth} m\n"
                order_text += f"   Narxi: {price:,} so'm\n"
                order_text += f"   Soni: {quantity}\n"
                order_text += f"   Jami: {item_total:,} so'm\n"
            
            order_text += f"\n💰 *Umumiy summa: {total:,} so'm*\n\n"
            order_text += "Tez orada operatorimiz siz bilan bog'lanadi! 📞"
            
            # Send confirmation
            await message.answer(order_text, parse_mode="Markdown")
            print(f"✅ Order confirmation sent to user {message.from_user.id}")
            print(f"💰 Total: {total:,} so'm")
            print(f"{'='*50}\n")
            
        else:
            print(f"❓ Unknown action: {data.get('action')}")
            
    except json.JSONDecodeError as e:
        print(f"❌ JSON decode error: {e}")
        await message.answer("❌ Ma'lumotni o'qishda xatolik!")
    except Exception as e:
        print(f"❌ Error processing web app data: {e}")
        import traceback
        traceback.print_exc()
        await message.answer("❌ Xatolik yuz berdi. Iltimos, qaytadan urinib ko'ring.")


async def main():
    """
    Main function to start the bot
    """
    try:
        print("="*50)
        print("Bot ishga tushdi! 🚀")
        print(f"WebApp URL: {WEBAPP_URL}")
        print("="*50)
    except UnicodeEncodeError:
        print("Bot ishga tushdi!")
        print(f"WebApp URL: {WEBAPP_URL}")
    
    # Start polling
    await dp.start_polling(bot)


if __name__ == '__main__':
    asyncio.run(main())
