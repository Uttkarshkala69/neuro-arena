```markdown
# 🧠 Neuro Arena

> **Neuromorphic AI-Driven Dynamic Difficulty in Real Time**
> 
> A 2D top-down arena shooter where the game learns, adapts, and evolves based on your playstyle.

[![Hackathon](https://img.shields.io/badge/NEURONEX-2026-blue?style=flat-square)](https://neuronex.org)
[![Engine](https://img.shields.io/badge/Godot-4.x-478CBF?style=flat-square&logo=godot-engine)](https://godotengine.org)
[![Language](https://img.shields.io/badge/GDScript-14A0FA?style=flat-square)](https://docs.godotengine.org/en/stable/getting_started/scripting/gdscript/index.html)

---

## 🎯 Objective

Survive against increasingly adaptive enemy waves while the AI Director continuously learns from player combat behavior and dynamically adjusts the challenge in real time.

---

## 🎮 The Problem

Traditional games employ **static difficulty scaling**—predefined difficulty tiers that remain constant regardless of player performance. Real players are dynamic: skill, stress, and confidence fluctuate continuously. Static difficulty creates cognitive misalignment, leading to frustration or disengagement.

**How can we engineer a game that maintains optimal challenge in real time?**

---

## 💡 The Solution

**Neuro Arena** implements a neuromorphic **AI Director** that continuously monitors player behavior and adapts opponent pressure in real time. The AI Director continuously analyzes player performance, movement patterns, stress indicators, and combat behavior to adjust enemy pressure in real time.

Instead of relying on predefined difficulty levels, Neuro Arena dynamically adapts the challenge using live player telemetry, creating a personalized gameplay experience.
---

## 🧬 How It Works

```
┌─────────────────┐
│  Player Input   │
│  + Movement     │
│  + Shooting     │
│  + Dodging      │
└────────┬────────┘
         │
         ▼
┌──────────────────────────┐
│   AI Director            │
│  ────────────────────    │
│  • Track Metrics         │
│  • Compute Scores        │
│  • Calculate Multiplier  │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│  Skill / Stress /        │
│  Confidence Analysis     │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│  Difficulty Adjustment   │
│  • Enemy Pressure        │
│  • Wave Intensity        │
│  • Spawn Behavior        │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│  Adaptive Gameplay       │
│  Experience              │
└──────────────────────────┘
```

---

## 📊 Metrics Tracked

| Category | Metrics |
|----------|---------|
| **Combat** | Accuracy, Damage Taken, Kills, Deaths |
| **Behavior** | Movement Patterns, Dash Frequency, Panic State |
| **Stress** | Consecutive Misses, Health State, Pressure Response |
| **Confidence** | Movement Predictability, Risk Taking, Survival Instinct |

---

## ⚔️ Features

✨ **AI-Driven Adaptation** – Real-time difficulty scaling based on neuromorphic analysis  
🎯 **Multiple Enemy Types** – Drones, Phantoms, Stalkers, and Boss encounters  
📈 **Live Telemetry** – Continuous player behavior monitoring and analysis  
🌊 **Dynamic Wave Management** – Enemy spawns adjust to player state  
🔄 **Event-Driven Architecture** – Scalable, modular system design  
⚡ **Adaptive Difficulty Engine** – Difficulty evolves continuously from live player telemetry  

---

## 🛠️ Tech Stack

- **Engine:** Godot 4.x
- **Language:** GDScript
- **Architecture:** Event-Driven
- **AI System:** Neuromorphic Adaptation Module
- **Core Systems:** Director, WaveManager, GameManager, Enemy AI

---

## 📂 Project Structure

```
neuro-arena/
├── assets/              # Sprites, audio, animations
├── scenes/
│   ├── Arena.tscn       # Main gameplay scene
│   └── Player.tscn      # Player character
├── scripts/
│   ├── Director.gd      # AI Director (core system)
│   ├── WaveManager.gd   # Wave spawning logic
│   ├── GameManager.gd   # Game state management
│   └── enemy/           # Enemy AI implementations
├── data/                # Configuration files
└── project.godot        # Godot project config
```

---

## 🚀 AI Adaptation Process

1. **Observe** – Director tracks 10+ player metrics each frame
2. **Analyze** – Computes Skill, Stress, and Confidence scores
3. **Calculate** – Generates real-time difficulty multiplier
4. **Adapt** – Adjusts enemy pressure, wave intensity, spawn behavior
5. **Repeat** – Continuous feedback loop for perfect pacing

---

## 🔮 Future Improvements

- [ ] Machine learning persistence (save learned player profiles)
- [ ] Neural network integration for deeper behavioral prediction
- [ ] Procedural boss generation based on player weakness detection
- [ ] Cross-run learning between play sessions
- [ ] Player feedback loop for difficulty tuning
- [ ] Advanced stress detection using biometric data

---

## 👾 Team

**Dead Coders**

* Uttkarsh Kala
* Aditya Sharma

---

## 📜 License

This project was developed for NEURONEX'26 Hackathon.

---

<div align="center">

**🧠 Built with neuromorphic intelligence. Plays with adaptive pressure. 🎮**

</div>
```
