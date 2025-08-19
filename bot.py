import discord
import asyncio
import a2s

TOKEN = ""
SERVER_ADDRESS = ("177.xxx.xxx.234", 27016)

intents = discord.Intents.default()
client = discord.Client(intents=intents)

async def update_status():
    while True:
        try:
            info = a2s.info(SERVER_ADDRESS, timeout=3.0)
            online_players = info.player_count
            max_capacity = info.max_players
            server_name = info.server_name

            status_msg = f"✅ {online_players}/{max_capacity} - {server_name[:40]}"
            await client.change_presence(activity=discord.Game(name=status_msg))

        except Exception as e:
            print(f"Error fetching server info: {e}")
            await client.change_presence(activity=discord.Game(name="❌ Server offline"))

        await asyncio.sleep(60)

@client.event
async def on_ready():
    print(f'Bot connected as {client.user}')
    client.loop.create_task(update_status())

client.run(TOKEN)

