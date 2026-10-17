import Foundation

private func ch(_ text: String, _ result: String, _ news: String, aura: Int, fol: Double,
                stats: [(StatKind, Int)] = [], npc: [(Trait, Int)] = []) -> Choice {
    Choice(text: text, result: result, news: news, aura: aura, fol: fol,
           stats: stats.map { StatDelta(kind: $0.0, v: $0.1) },
           npc: npc.map { NPCDelta(trait: $0.0, d: $0.1) })
}

enum Story {
    static let all: [StoryEvent] = [
        StoryEvent(id: "leak", emoji: "🎭",
                   text: "Anonymous “sources” are flooding the timeline with fabricated screenshots about you. How do you respond?",
                   choices: [
                    ch("Burn it down: post a savage clapback at midnight",
                       "By morning the rumor is dead, your clapback is everywhere, and even {hater} admits it was funny.",
                       "{me} DESTROYS the rumor mill with a midnight clapback",
                       aura: 7, fol: 9, stats: [(.humor, 4), (.edge, 3)], npc: [(.hater, -1), (.gossip, 1)]),
                    ch("Drop receipts: post the real messages and notes",
                       "The receipts check out. The rumor collapses and people call you 'the transparent one'.",
                       "{me} posts receipts. The rumor mill goes quiet.",
                       aura: 10, fol: 5, stats: [(.charm, 4)], npc: [(.gossip, -1), (.wholesome, 1)]),
                    ch("Stay silent. Let the work speak.",
                       "Silence reads as guilt to some and class to others. The story cools off slowly.",
                       "{me} says nothing. Fans are divided.",
                       aura: -2, fol: -3, stats: [(.mystery, 4)], npc: [(.gossip, 1), (.hype, -1)])
                   ]),
        StoryEvent(id: "brand", emoji: "💸",
                   text: "A questionable energy-drink brand slides into your DMs with a huge offer. {mogul} says take it.",
                   choices: [
                    ch("Take the bag",
                       "The check clears. The timeline calls you a sellout for exactly 48 hours, then moves on.",
                       "{me} signs a mega energy-drink deal",
                       aura: -4, fol: 6, stats: [(.edge, 3)], npc: [(.mogul, 1), (.wholesome, -1)]),
                    ch("Negotiate: only if they fund a charity drive",
                       "They agree. The deal becomes a feel-good story and nobody can drag you for it.",
                       "{me} turns a brand deal into a charity drive",
                       aura: 8, fol: 3, stats: [(.charm, 4)], npc: [(.wholesome, 1), (.mogul, -1)]),
                    ch("Roast the brand publicly",
                       "The roast goes viral. The brand replies with a sad emoji. Legends.",
                       "{me} roasts a brand deal on main",
                       aura: 3, fol: 11, stats: [(.humor, 4), (.edge, 2)], npc: [(.mogul, -1), (.hater, 1)])
                   ]),
        StoryEvent(id: "subtweet", emoji: "🗡️",
                   text: "{hater} posts a vague subtweet that is obviously about you. The replies are picking sides.",
                   choices: [
                    ch("Quote it with a joke",
                       "The joke lands. The replies switch sides mid-thread and {hater} deletes it.",
                       "{me} wins the subtweet war with one joke",
                       aura: 5, fol: 6, stats: [(.humor, 4)], npc: [(.hater, -1)]),
                    ch("DM them privately and settle it",
                       "It turns out to be a misunderstanding. You walk away with a new ally.",
                       "{me} and {hater} seen squashing the beef",
                       aura: 6, fol: 1, stats: [(.charm, 3)], npc: [(.hater, 1)]),
                    ch("Escalate: dig up their old posts",
                       "It gets ugly. You win the day, but people remember how.",
                       "{me} expose thread torches {hater}",
                       aura: -9, fol: 12, stats: [(.edge, 5)], npc: [(.hater, -1), (.gossip, 1)])
                   ]),
        StoryEvent(id: "oldpost", emoji: "🕰️",
                   text: "A cringe post from years ago resurfaces and trends. Everyone has screenshots.",
                   choices: [
                    ch("Delete it and hope for the best",
                       "People screenshot the deletion too. It fades, but it stings.",
                       "{me} deletes old post. Screenshots live forever.",
                       aura: -6, fol: -4, stats: [(.mystery, 3)], npc: [(.gossip, 1)]),
                    ch("Own it: repost with 'yes, I did that'",
                       "The honesty is disarming. The timeline decides you're the funniest person alive.",
                       "{me} owns cringe past post and wins the internet",
                       aura: 9, fol: 10, stats: [(.humor, 4), (.charm, 3)], npc: [(.hater, -1)]),
                    ch("Claim your account was hacked",
                       "Nobody buys it. {hater} has the receipts and the replies are brutal.",
                       "{me} claims 'hacked account'. Nobody believes it.",
                       aura: -10, fol: -6, stats: [(.edge, 2)], npc: [(.hater, 1), (.gossip, 1)])
                   ]),
        StoryEvent(id: "fans", emoji: "📸",
                   text: "Fans organize a surprise meetup outside your place and it's getting chaotic.",
                   choices: [
                    ch("Go out and take photos with everyone",
                       "It's chaotic and wholesome. The photos are everywhere by lunch.",
                       "{me} surprises fans outside with a mini meetup",
                       aura: 8, fol: 8, stats: [(.charm, 4)], npc: [(.hype, 1)]),
                    ch("Send pizza and a voice note",
                       "The crowd loses it. The voice note gets replayed 3 million times.",
                       "{me} sends pizza to fans waiting outside",
                       aura: 6, fol: 4, stats: [(.charm, 2), (.mystery, 2)], npc: [(.wholesome, 1)]),
                    ch("Call security",
                       "Someone filmed the whole thing. The clip is not flattering.",
                       "{me} calls security on fan meetup",
                       aura: -8, fol: -5, stats: [(.mystery, 3)], npc: [(.wholesome, -1), (.hype, -1)])
                   ]),
        StoryEvent(id: "friend", emoji: "🤝",
                   text: "{wholesome} asks you to promote their small project, but honestly it's rough.",
                   choices: [
                    ch("Promote it honestly, flaws and all",
                       "People love the honesty. {wholesome} cries happy tears and the project actually improves.",
                       "{me} gives honest shoutout to {wholesome}",
                       aura: 4, fol: 1, stats: [(.charm, 3)], npc: [(.wholesome, 1)]),
                    ch("Hype it up carefully, focusing on the good parts",
                       "Smart play. Everyone wins and nobody feels lied to.",
                       "{me} shouts out {wholesome}'s project",
                       aura: 6, fol: 3, stats: [(.charm, 2), (.humor, 1)], npc: [(.wholesome, 1)]),
                    ch("Ghost them",
                       "They notice. The group chat notices. Everyone notices.",
                       "{wholesome} says they feel ignored by {me}",
                       aura: -7, fol: -2, stats: [(.edge, 2)], npc: [(.wholesome, -1)])
                   ]),
        StoryEvent(id: "glitch", emoji: "📹",
                   text: "You went live and your camera glitched. For three minutes the entire internet watched the wrong filter.",
                   choices: [
                    ch("Lean into it. Do a bit.",
                       "The bit becomes a meme. Clips are everywhere before you finish the stream.",
                       "{me}'s glitched live stream becomes a meme",
                       aura: 9, fol: 14, stats: [(.humor, 5)], npc: [(.chaos, 1)]),
                    ch("End the stream and apologize",
                       "Classy, but a bit boring. People move on quickly.",
                       "{me} ends stream after camera glitch",
                       aura: 1, fol: -2, stats: [(.charm, 2)], npc: []),
                    ch("Blame {chaos}",
                       "{chaos} plays along and makes it worse. It's the best content of the week.",
                       "{me} blames {chaos} for glitch. Chaos ensues.",
                       aura: -5, fol: 6, stats: [(.humor, 3), (.edge, 2)], npc: [(.chaos, 1)])
                   ]),
        StoryEvent(id: "awards", emoji: "🏆",
                   text: "Nominations drop and you're not on the list. {hype} is furious on your behalf.",
                   choices: [
                    ch("Congratulate the winners graciously",
                       "Unbelievably mature. Even your haters respect it.",
                       "{me} congratulates nominees after being snubbed",
                       aura: 9, fol: 3, stats: [(.charm, 4)], npc: [(.hater, -1), (.hype, 1)]),
                    ch("Post a long 'rigged' thread",
                       "The thread goes nuclear. Half the internet agrees, half rolls their eyes.",
                       "{me} says the awards are rigged",
                       aura: -4, fol: 10, stats: [(.edge, 4)], npc: [(.hype, 1), (.mogul, -1)]),
                    ch("Throw your own award show",
                       "The show is a disaster in the best way. Everyone is talking about it.",
                       "{me} announces their own award show",
                       aura: 5, fol: 15, stats: [(.humor, 3), (.mystery, 2)], npc: [(.chaos, 1), (.mogul, 1)])
                   ]),
        StoryEvent(id: "blind", emoji: "🕵️",
                   text: "A gossip page posts a blind item everyone knows is about you.",
                   choices: [
                    ch("Confirm it with a wink emoji",
                       "The internet explodes. The gossip page posts an apology to its own followers.",
                       "{me} confirms blind item with a wink",
                       aura: 3, fol: 13, stats: [(.mystery, 4), (.edge, 2)], npc: [(.gossip, 1)]),
                    ch("Deny it flatly",
                       "The denial sounds suspicious. The rumor takes on a life of its own.",
                       "{me} denies blind item. Nobody is convinced.",
                       aura: -3, fol: -2, stats: [(.charm, 1)], npc: [(.gossip, 1)]),
                    ch("Post something unrelated and iconic",
                       "The timeline gets so distracted by your new post that the blind item is forgotten.",
                       "{me} posts iconic photo. Blind item forgotten.",
                       aura: 7, fol: 7, stats: [(.humor, 2), (.mystery, 3)], npc: [(.hype, 1)])
                   ]),
        StoryEvent(id: "collab", emoji: "🎬",
                   text: "{mogul} offers a big collab with {hater}, your most annoying rival.",
                   choices: [
                    ch("Accept and split the credits",
                       "Surprisingly good chemistry. Fans call it 'the crossover of the year'.",
                       "{me} and {hater} announce surprise collab",
                       aura: 6, fol: 12, stats: [(.charm, 3)], npc: [(.hater, 1), (.mogul, 1)]),
                    ch("Decline. You don't need them.",
                       "Bold. The timeline admires your confidence but {mogul} is cold for a while.",
                       "{me} turns down {hater} collab",
                       aura: 1, fol: -3, stats: [(.edge, 3)], npc: [(.mogul, -1)]),
                    ch("Accept, then sabotage it as a bit",
                       "The sabotage is hilarious. Everyone is furious. Everyone is also watching.",
                       "{me} sabotages collab live. Internet in meltdown.",
                       aura: -2, fol: 18, stats: [(.humor, 4), (.edge, 3)], npc: [(.hater, -1), (.mogul, -1)])
                   ])
    ]
}

enum Lines {
    static let pos: [Trait: [String]] = [
        .hype: ["LETS GOOO 🔥🔥", "ok this is actually so good", "you just carried the whole timeline", "not you eating AGAIN 😭"],
        .hater: ["fine. that was decent. don't let it go to your head.", "ugh. annoyingly good.", "i hate that i liked this"],
        .wholesome: ["this made my whole day 🥹", "so proud of you, genuinely", "you're such a good presence on here"],
        .gossip: ["ok i'm telling everyone about this", "the group chat is going to lose it", "noted. very noted. 👀"],
        .mogul: ["clean. let's talk numbers.", "on-brand. keep going.", "engagement looks strong. slide in my DMs."],
        .chaos: ["i have no idea what this is but i LOVE it", "unhinged. perfect. no notes", "quote tweeting this at 3am"]
    ]
    static let neg: [Trait: [String]] = [
        .hype: ["ok that one was a bit much ngl", "bro. why."],
        .hater: ["cringe. delete this.", "who asked?", "this is exactly why nobody takes you seriously"],
        .wholesome: ["i'm worried this will hurt someone 😔", "maybe think before posting? just a thought"],
        .gossip: ["oh this is JUICY. screenshotting.", "everyone's talking about this and not in a good way 👀"],
        .mogul: ["bad for the brand. fix it.", "this is going to cost you."],
        .chaos: ["a bold choice. i'm popping popcorn 🍿", "you really did that huh"]
    ]
    static let dm: [Trait: [String]] = [
        .hype: ["YOOO you actually messaged me?? let's go", "ok you're cool. we should collab fr", "i hype you up in my head daily 😭"],
        .hater: ["...hi. i guess.", "i don't do small talk. but fine, hello.", "you're less annoying than most. congrats."],
        .wholesome: ["aww hi!! how's your day going?", "you're so sweet for messaging, thank you 💛", "i'm always here if you wanna talk"],
        .gossip: ["ok sit. i have SO much to tell you", "did you hear about what happened last night??", "you didn't hear it from me, but..."],
        .mogul: ["send me your numbers and we'll talk.", "interesting. what's your angle?", "let's do lunch. metaphorically."],
        .chaos: ["wanna do something illegal (legal) with me", "i just ate a lemon whole. anyway hi", "ok but what if we both quit and start a band"]
    ]
    static let feed: [Trait: [String]] = [
        .hype: ["new week. new W's. let's get it 💪", "drop your best moment this week below 👇", "the vibes are IMMACULATE today"],
        .hater: ["everyone's so fake. refreshing to be me.", "unpopular opinion: most of you are overrated.", "if you liked that post you have bad taste. sorry."],
        .wholesome: ["be kind to someone today. it's free 🌷", "grateful for my little corner of the internet.", "made cookies. sending virtual ones to you all 🍪"],
        .gossip: ["not me hearing something wild just now 👀", "tea is steeping. stay tuned.", "someone's about to get exposed. not naming names."],
        .mogul: ["investing in myself. you should too.", "numbers don't lie. growth is up 18%.", "announcing something huge soon. stay locked in."],
        .chaos: ["i just renamed myself. don't ask.", "what if the moon is a lamp", "today's mood: stack of pancakes and no plan"]
    ]
}
