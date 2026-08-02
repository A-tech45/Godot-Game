# Territory Break — Free Multiplayer Relay Server (Render.com Deployment)

A lightweight Node.js WebSocket relay server for Territory Break. It forwards game data and lobby messages between players in the same room.

---

## 🚀 100% Free Deployment on Render.com (No Credit Card Required)

Render.com provides free web service hosting without requiring any credit card or payment details.

### Step 1: Push Code to GitHub

Make sure your project repository (including the `relay_server` folder) is pushed to your GitHub account.

### Step 2: Sign Up / Sign In on Render

1. Go to [render.com](https://render.com).
2. Click **Get Started for Free** or **Sign In**.
3. Sign in using your **GitHub account**.

### Step 3: Create a Web Service

1. Click **New +** at the top right and select **Web Service**.
2. Select **Build and deploy from a Git repository**.
3. Choose your repository (`new-game-project`).
4. Fill in the following configurations:
   - **Name**: `territory-break-relay` (or any unique name)
   - **Language**: `Node`
   - **Root Directory**: `relay_server`
   - **Build Command**: `npm install`
   - **Start Command**: `node server.js`
   - **Instance Type**: **Free**
5. Click **Create Web Service**.

> **Note on Free Tier Sleeping behavior**: On Render's Free tier, the server automatically sleeps after 15 minutes of inactivity (when no players are active). When a player hosts or joins a room, Render spins the server back up in ~30 seconds. The game includes auto-retry handling to seamlessly wait for the server to wake up!

---

## 🛠️ Step 4: Connect Game to Your Relay Server

Once Render finishes building, copy your service's URL from the top of your Render dashboard.
It will look something like:
`https://territory-break-relay.onrender.com`

Convert `https://` or `http://` to WebSocket protocol (`wss://`):
`wss://territory-break-relay.onrender.com`

Open `scripts/network_manager.gd` in Godot and update `RELAY_URL` (around line 18):

```gdscript
const RELAY_URL: String = "wss://territory-break-relay.onrender.com"
```

Save the script and export/build your game!

---

## 💻 Local Testing (Running Server Locally)

To test multiplayer on your local computer before deploying:

```bash
cd relay_server
npm install
npm start
```

In `scripts/network_manager.gd`, set:
```gdscript
const RELAY_URL: String = "ws://localhost:9090"
```

Runs on port `9090` by default.
