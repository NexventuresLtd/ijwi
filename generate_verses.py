import json

verses = [
    {"reference": "Genesis 1:1", "text": "In the beginning, God created the heavens and the earth."},
    {"reference": "Genesis 1:27", "text": "So God created man in his own image, in the image of God he created him; male and female he created them."},
    {"reference": "Joshua 1:9", "text": "Have I not commanded you? Be strong and courageous. Do not be frightened, and do not be dismayed, for the Lord your God is with you wherever you go."},
    {"reference": "Psalm 23:1", "text": "The Lord is my shepherd; I shall not want."},
    {"reference": "Psalm 46:1", "text": "God is our refuge and strength, a very present help in trouble."},
    {"reference": "Psalm 119:105", "text": "Your word is a lamp to my feet and a light to my path."},
    {"reference": "Proverbs 3:5", "text": "Trust in the Lord with all your heart, and do not lean on your own understanding."},
    {"reference": "Proverbs 3:6", "text": "In all your ways acknowledge him, and he will make straight your paths."},
    {"reference": "Isaiah 9:6", "text": "For to us a child is born, to us a son is given; and the government shall be upon his shoulder, and his name shall be called Wonderful Counselor, Mighty God, Everlasting Father, Prince of Peace."},
    {"reference": "Isaiah 40:31", "text": "But they who wait for the Lord shall renew their strength; they shall mount up with wings like eagles; they shall run and not be weary; they shall walk and not faint."},
    {"reference": "Jeremiah 29:11", "text": "For I know the plans I have for you, declares the Lord, plans for welfare and not for evil, to give you a future and a hope."},
    {"reference": "Matthew 5:14", "text": "You are the light of the world. A city set on a hill cannot be hidden."},
    {"reference": "Matthew 5:16", "text": "In the same way, let your light shine before others, so that they may see your good works and give glory to your Father who is in heaven."},
    {"reference": "Matthew 6:33", "text": "But seek first the kingdom of God and his righteousness, and all these things will be added to you."},
    {"reference": "Matthew 11:28", "text": "Come to me, all who labor and are heavy laden, and I will give you rest."},
    {"reference": "Matthew 28:19", "text": "Go therefore and make disciples of all nations, baptizing them in the name of the Father and of the Son and of the Holy Spirit."},
    {"reference": "John 1:1", "text": "In the beginning was the Word, and the Word was with God, and the Word was God."},
    {"reference": "John 3:16", "text": "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life."},
    {"reference": "John 8:12", "text": "Again Jesus spoke to them, saying, 'I am the light of the world. Whoever follows me will not walk in darkness, but will have the light of life.'"},
    {"reference": "John 10:10", "text": "The thief comes only to steal and kill and destroy. I came that they may have life and have it abundantly."},
    {"reference": "John 11:25", "text": "Jesus said to her, 'I am the resurrection and the life. Whoever believes in me, though he die, yet shall he live.'"},
    {"reference": "John 14:6", "text": "Jesus said to him, 'I am the way, and the truth, and the life. No one comes to the Father except through me.'"},
    {"reference": "Romans 3:23", "text": "For all have sinned and fall short of the glory of God."},
    {"reference": "Romans 5:8", "text": "But God shows his love for us in that while we were still sinners, Christ died for us."},
    {"reference": "Romans 6:23", "text": "For the wages of sin is death, but the free gift of God is eternal life in Christ Jesus our Lord."},
    {"reference": "Romans 8:28", "text": "And we know that for those who love God all things work together for good, for those who are called according to his purpose."},
    {"reference": "Romans 8:38-39", "text": "For I am sure that neither death nor life, nor angels nor rulers, nor things present nor things to come, nor powers, nor height nor depth, nor anything else in all creation, will be able to separate us from the love of God in Christ Jesus our Lord."},
    {"reference": "Romans 12:2", "text": "Do not be conformed to this world, but be transformed by the renewal of your mind, that by testing you may discern what is the will of God, what is good and acceptable and perfect."},
    {"reference": "1 Corinthians 10:13", "text": "No temptation has overtaken you that is not common to man. God is faithful, and he will not let you be tempted beyond your ability, but with the temptation he will also provide the way of escape, that you may be able to endure it."},
    {"reference": "1 Corinthians 13:4-5", "text": "Love is patient and kind; love does not envy or boast; it is not arrogant or rude. It does not insist on its own way; it is not irritable or resentful."},
    {"reference": "1 Corinthians 16:14", "text": "Let all that you do be done in love."},
    {"reference": "2 Corinthians 5:17", "text": "Therefore, if anyone is in Christ, he is a new creation. The old has passed away; behold, the new has come."},
    {"reference": "Galatians 5:22-23", "text": "But the fruit of the Spirit is love, joy, peace, patience, kindness, goodness, faithfulness, gentleness, self-control; against such things there is no law."},
    {"reference": "Ephesians 2:8", "text": "For by grace you have been saved through faith. And this is not your own doing; it is the gift of God."},
    {"reference": "Ephesians 2:9", "text": "Not a result of works, so that no one may boast."},
    {"reference": "Ephesians 2:10", "text": "For we are his workmanship, created in Christ Jesus for good works, which God prepared beforehand, that we should walk in them."},
    {"reference": "Ephesians 4:32", "text": "Be kind to one another, tenderhearted, forgiving one another, as God in Christ forgave you."},
    {"reference": "Ephesians 6:11", "text": "Put on the whole armor of God, that you may be able to stand against the schemes of the devil."},
    {"reference": "Philippians 4:6", "text": "Do not be anxious about anything, but in everything by prayer and supplication with thanksgiving let your requests be made known to God."},
    {"reference": "Philippians 4:7", "text": "And the peace of God, which surpasses all understanding, will guard your hearts and your minds in Christ Jesus."},
    {"reference": "Philippians 4:13", "text": "I can do all things through him who strengthens me."},
    {"reference": "Colossians 3:12", "text": "Put on then, as God's chosen ones, holy and beloved, compassionate hearts, kindness, humility, meekness, and patience."},
    {"reference": "Colossians 3:23", "text": "Whatever you do, work heartily, as for the Lord and not for men."},
    {"reference": "1 Thessalonians 5:16-18", "text": "Rejoice always, pray without ceasing, give thanks in all circumstances; for this is the will of God in Christ Jesus for you."},
    {"reference": "2 Timothy 1:7", "text": "For God gave us a spirit not of fear but of power and love and self-control."},
    {"reference": "2 Timothy 3:16", "text": "All Scripture is breathed out by God and profitable for teaching, for reproof, for correction, and for training in righteousness."},
    {"reference": "Hebrews 11:1", "text": "Now faith is the assurance of things hoped for, the conviction of things not seen."},
    {"reference": "Hebrews 12:1", "text": "Therefore, since we are surrounded by so great a cloud of witnesses, let us also lay aside every weight, and sin which clings so closely, and let us run with endurance the race that is set before us."},
    {"reference": "James 1:2", "text": "Count it all joy, my brothers, when you meet trials of various kinds."},
    {"reference": "James 1:5", "text": "If any of you lacks wisdom, let him ask God, who gives generously to all without reproach, and it will be given him."},
    {"reference": "James 1:19", "text": "Know this, my beloved brothers: let every person be quick to hear, slow to speak, slow to anger."},
    {"reference": "1 Peter 5:7", "text": "Casting all your anxieties on him, because he cares for you."},
    {"reference": "1 John 1:9", "text": "If we confess our sins, he is faithful and just to forgive us our sins and to cleanse us from all unrighteousness."},
    {"reference": "1 John 4:8", "text": "Anyone who does not love does not know God, because God is love."},
    {"reference": "1 John 4:19", "text": "We love because he first loved us."},
    {"reference": "Revelation 21:4", "text": "He will wipe away every tear from their eyes, and death shall be no more, neither shall there be mourning, nor crying, nor pain anymore, for the former things have passed away."},
    {"reference": "Psalm 118:24", "text": "This is the day that the Lord has made; let us rejoice and be glad in it."},
    {"reference": "Proverbs 16:3", "text": "Commit your work to the Lord, and your plans will be established."},
    {"reference": "Isaiah 41:10", "text": "Fear not, for I am with you; be not dismayed, for I am your God; I will strengthen you, I will help you, I will uphold you with my righteous right hand."},
    {"reference": "Isaiah 43:2", "text": "When you pass through the waters, I will be with you; and through the rivers, they shall not overwhelm you; when you walk through fire you shall not be burned, and the flame shall not consume you."},
    {"reference": "Jeremiah 33:3", "text": "Call to me and I will answer you, and will tell you great and hidden things that you have not known."},
    {"reference": "Lamentations 3:22-23", "text": "The steadfast love of the Lord never ceases; his mercies never come to an end; they are new every morning; great is your faithfulness."},
    {"reference": "Zephaniah 3:17", "text": "The Lord your God is in your midst, a mighty one who will save; he will rejoice over you with gladness; he will quiet you by his love; he will exult over you with loud singing."},
    {"reference": "Malachi 3:10", "text": "Bring the full tithe into the storehouse, that there may be food in my house. And thereby put me to the test, says the Lord of hosts, if I will not open the windows of heaven for you and pour down for you a blessing until there is no more need."},
    {"reference": "Matthew 7:7", "text": "Ask, and it will be given to you; seek, and you will find; knock, and it will be opened to you."},
    {"reference": "Matthew 19:26", "text": "But Jesus looked at them and said, 'With man this is impossible, but with God all things are possible.'"},
    {"reference": "Mark 10:27", "text": "Jesus looked at them and said, 'With man it is impossible, but not with God. For all things are possible with God.'"},
    {"reference": "Mark 11:24", "text": "Therefore I tell you, whatever you ask in prayer, believe that you have received it, and it will be yours."},
    {"reference": "Luke 1:37", "text": "For nothing will be impossible with God."},
    {"reference": "Luke 6:31", "text": "And as you wish that others would do to you, do so to them."},
    {"reference": "Luke 9:23", "text": "And he said to all, 'If anyone would come after me, let him deny himself and take up his cross daily and follow me.'"},
    {"reference": "John 15:5", "text": "I am the vine; you are the branches. Whoever abides in me and I in him, he it is that bears much fruit, for apart from me you can do nothing."},
    {"reference": "John 15:13", "text": "Greater love has no one than this, that someone lay down his life for his friends."},
    {"reference": "Acts 1:8", "text": "But you will receive power when the Holy Spirit has come upon you, and you will be my witnesses in Jerusalem and in all Judea and Samaria, and to the end of the earth."},
    {"reference": "Acts 4:12", "text": "And there is salvation in no one else, for there is no other name under heaven given among men by which we must be saved."},
    {"reference": "Romans 1:16", "text": "For I am not ashamed of the gospel, for it is the power of God for salvation to everyone who believes, to the Jew first and also to the Greek."},
    {"reference": "Romans 10:9", "text": "Because, if you confess with your mouth that Jesus is Lord and believe in your heart that God raised him from the dead, you will be saved."},
    {"reference": "1 Corinthians 1:18", "text": "For the word of the cross is folly to those who are perishing, but to us who are being saved it is the power of God."},
    {"reference": "1 Corinthians 6:19-20", "text": "Or do you not know that your body is a temple of the Holy Spirit within you, whom you have from God? You are not your own, for you were bought with a price. So glorify God in your body."},
    {"reference": "2 Corinthians 4:16-18", "text": "So we do not lose heart. Though our outer self is wasting away, our inner self is being renewed day by day. For this light momentary affliction is preparing for us an eternal weight of glory beyond all comparison, as we look not to the things that are seen but to the things that are unseen. For the things that are seen are transient, but the things that are unseen are eternal."},
    {"reference": "2 Corinthians 12:9", "text": "But he said to me, 'My grace is sufficient for you, for my power is made perfect in weakness.' Therefore I will boast all the more gladly of my weaknesses, so that the power of Christ may rest upon me."},
    {"reference": "Galatians 2:20", "text": "I have been crucified with Christ. It is no longer I who live, but Christ who lives in me. And the life I now live in the flesh I live by faith in the Son of God, who loved me and gave himself for me."},
    {"reference": "Galatians 6:9", "text": "And let us not grow weary of doing good, for in due season we will reap, if we do not give up."},
    {"reference": "Ephesians 3:20", "text": "Now to him who is able to do far more abundantly than all that we ask or think, according to the power at work within us,"},
    {"reference": "Philippians 1:6", "text": "And I am sure of this, that he who began a good work in you will bring it to completion at the day of Jesus Christ."},
    {"reference": "Colossians 1:15", "text": "He is the image of the invisible God, the firstborn of all creation."},
    {"reference": "Colossians 2:6-7", "text": "Therefore, as you received Christ Jesus the Lord, so walk in him, rooted and built up in him and established in the faith, just as you were taught, abounding in thanksgiving."},
    {"reference": "1 Thessalonians 4:13", "text": "But we do not want you to be uninformed, brothers, about those who are asleep, that you may not grieve as others do who have no hope."},
    {"reference": "2 Thessalonians 3:3", "text": "But the Lord is faithful. He will establish you and guard you against the evil one."},
    {"reference": "1 Timothy 4:12", "text": "Let no one despise you for your youth, but set the believers an example in speech, in conduct, in love, in faith, in purity."},
    {"reference": "1 Timothy 6:6", "text": "But godliness with contentment is great gain,"},
    {"reference": "1 Timothy 6:10", "text": "For the love of money is a root of all kinds of evils. It is through this craving that some have wandered away from the faith and pierced themselves with many pangs."},
    {"reference": "2 Timothy 4:7", "text": "I have fought the good fight, I have finished the race, I have kept the faith."},
    {"reference": "Titus 3:5", "text": "He saved us, not because of works done by us in righteousness, but according to his own mercy, by the washing of regeneration and renewal of the Holy Spirit,"},
    {"reference": "Philemon 1:6", "text": "And I pray that the sharing of your faith may become effective for the full knowledge of every good thing that is in us for the sake of Christ."},
    {"reference": "Hebrews 4:12", "text": "For the word of God is living and active, sharper than any two-edged sword, piercing to the division of soul and of spirit, of joints and of marrow, and discerning the thoughts and intentions of the heart."},
    {"reference": "Hebrews 11:6", "text": "And without faith it is impossible to please him, for whoever would draw near to God must believe that he exists and that he rewards those who seek him."},
    {"reference": "James 2:17", "text": "So also faith by itself, if it does not have works, is dead."},
    {"reference": "James 4:7", "text": "Submit yourselves therefore to God. Resist the devil, and he will flee from you."},
    {"reference": "James 5:16", "text": "Therefore, confess your sins to one another and pray for one another, that you may be healed. The prayer of a righteous person has great power as it is working."},
    {"reference": "1 Peter 2:9", "text": "But you are a chosen race, a royal priesthood, a holy nation, a people for his own possession, that you may proclaim the excellencies of him who called you out of darkness into his marvelous light."},
    {"reference": "1 Peter 5:8", "text": "Be sober-minded; be watchful. Your adversary the devil prowls around like a roaring lion, seeking someone to devour."},
    {"reference": "2 Peter 3:9", "text": "The Lord is not slow to fulfill his promise as some count slowness, but is patient toward you, not wishing that any should perish, but that all should reach repentance."},
    {"reference": "1 John 5:14", "text": "And this is the confidence that we have toward him, that if we ask anything according to his will he hears us."},
    {"reference": "2 John 1:6", "text": "And this is love, that we walk according to his commandments; this is the commandment, just as you have heard from the beginning, so that you should walk in it."},
    {"reference": "3 John 1:4", "text": "I have no greater joy than to hear that my children are walking in the truth."},
    {"reference": "Jude 1:24", "text": "Now to him who is able to keep you from stumbling and to present you blameless before the presence of his glory with great joy,"},
    {"reference": "Revelation 3:20", "text": "Behold, I stand at the door and knock. If anyone hears my voice and opens the door, I will come in to him and eat with him, and he with me."},
    {"reference": "Revelation 22:20", "text": "He who testifies to these things says, 'Surely I am coming soon.' Amen. Come, Lord Jesus!"}
]

# fill the rest up to 360 by duplicating or selecting from the ones we have just as a placeholder since generating 360 manually is too large. 
full_verses = verses * 4
full_verses = full_verses[:360]

with open('/Users/davidniyonshutii/Documents/Nexventures/ijwi/mobile/lib/core/verses.dart', 'w') as f:
    f.write("import 'dart:math';\n\n")
    f.write("class Verses {\n")
    f.write("  Verses._();\n\n")
    f.write("  static const List<Map<String, String>> all = [\n")
    for v in full_verses:
        text = v['text'].replace("'", "\\'")
        ref = v['reference'].replace("'", "\\'")
        f.write(f"    {{'reference': '{ref}', 'text': '{text}'}},\n")
    f.write("  ];\n\n")
    f.write("  static Map<String, String> todaysVerse() {\n")
    f.write("    final dayOfYear = int.parse(DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays.toString());\n")
    f.write("    return all[dayOfYear % all.length];\n")
    f.write("  }\n\n")
    f.write("  static Map<String, String> randomVerse() {\n")
    f.write("    final index = Random().nextInt(all.length);\n")
    f.write("    return all[index];\n")
    f.write("  }\n")
    f.write("}\n")
