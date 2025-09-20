import discord
import asyncio
import a2s  # Agora é o pacote certo

TOKEN = "hash-key"
SERVER_ADDRESS = ("177.207.165.234", 27016)

intents = discord.Intents.default()
client = discord.Client(intents=intents)

async def atualizar_status():
    while True:
        try:
            info = a2s.info(SERVER_ADDRESS, timeout=3.0)
            jogadores_online = info.player_count
            capacidade = info.max_players
            nome_servidor = info.server_name

            status_msg = f"✅ {jogadores_online}/{capacidade} - {nome_servidor[:40]}"
            await client.change_presence(activity=discord.Game(name=status_msg))

        except Exception as e:
            print(f"Erro ao consultar o servidor: {e}")
            await client.change_presence(activity=discord.Game(name="❌ Servidor offline"))

        await asyncio.sleep(60)

@client.event
async def on_ready():
    print(f'Bot conectado como {client.user}')
    client.loop.create_task(atualizar_status())

client.run(TOKEN)

