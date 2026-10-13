import QtQuick
pragma Singleton

QtObject {
    property var categories: ["All"]
    property string currentCategory: SettingsService.quoteCategory
    property var quotes: [{
        "text": "Waste no more time arguing about what a good man should be. Be one.",
        "author": "Marcus Aurelius",
        "category": "Philosophy"
    }, {
        "text": "We suffer more often in imagination than in reality.",
        "author": "Seneca",
        "category": "Philosophy"
    }, {
        "text": "The only true wisdom is in knowing you know nothing.",
        "author": "Socrates",
        "category": "Philosophy"
    }, {
        "text": "Life is what happens when you're busy making other plans.",
        "author": "John Lennon",
        "category": "Life"
    }, {
        "text": "It is not that we have a short time to live, but that we waste a lot of it.",
        "author": "Seneca",
        "category": "Philosophy"
    }, {
        "text": "You have power over your mind - not outside events. Realize this, and you will find strength.",
        "author": "Marcus Aurelius",
        "category": "Philosophy"
    }, {
        "text": "Talk is cheap. Show me the code.",
        "author": "Linus Torvalds",
        "category": "Programming"
    }, {
        "text": "First, solve the problem. Then, write the code.",
        "author": "John Johnson",
        "category": "Programming"
    }, {
        "text": "Make it work, make it right, make it fast.",
        "author": "Kent Beck",
        "category": "Programming"
    }, {
        "text": "Programs must be written for people to read, and only incidentally for machines to execute.",
        "author": "Harold Abelson",
        "category": "Programming"
    }, {
        "text": "Code is like humor. When you have to explain it, it’s bad.",
        "author": "Cory House",
        "category": "Programming"
    }, {
        "text": "Simplicity is the soul of efficiency.",
        "author": "Austin Freeman",
        "category": "Programming"
    }, {
        "text": "There are only two hard things in Computer Science: cache invalidation and naming things.",
        "author": "Phil Karlton",
        "category": "Programming"
    }, {
        "text": "In order to understand recursion, one must first understand recursion.",
        "author": "Anonymous",
        "category": "Programming"
    }, {
        "text": "It's not a bug – it's an undocumented feature.",
        "author": "Anonymous",
        "category": "Humor"
    }, {
        "text": "The best thing about a boolean is even if you are wrong, you are only off by a bit.",
        "author": "Anonymous",
        "category": "Humor"
    }, {
        "text": "Complexity is your enemy. Any fool can make something complicated.",
        "author": "Tony Hoare",
        "category": "Programming"
    }, {
        "text": "Before software can be reusable it first has to be usable.",
        "author": "Ralph Johnson",
        "category": "Programming"
    }, {
        "text": "Premature optimization is the root of all evil.",
        "author": "Donald Knuth",
        "category": "Programming"
    }, {
        "text": "The function of good software is to make the invisible visible.",
        "author": "Steve McConnell",
        "category": "Programming"
    }, {
        "text": "Any fool can write code that a computer can understand. Good programmers write code that humans can understand.",
        "author": "Martin Fowler",
        "category": "Programming"
    }, {
        "text": "Truth can only be found in one place: the code.",
        "author": "Robert C. Martin",
        "category": "Programming"
    }, {
        "text": "Happiness is not an ideal of reason, but of imagination.",
        "author": "Immanuel Kant",
        "category": "Philosophy"
    }, {
        "text": "We are what we repeatedly do. Excellence, then, is not an act, but a habit.",
        "author": "Aristotle",
        "category": "Philosophy"
    }, {
        "text": "A computer once beat me at chess, but it was no match for me at kick boxing.",
        "author": "Emo Philips",
        "category": "Humor"
    }, {
        "text": "Youth is happy because it has the capacity to see beauty. Anyone who keeps the ability to see beauty never grows old.",
        "author": "Franz Kafka",
        "category": "Life"
    }, {
        "text": "By believing passionately in something that still does not exist, we create it.",
        "author": "Franz Kafka",
        "category": "Philosophy"
    }, {
        "text": "He who has a why to live for can bear almost any how.",
        "author": "Friedrich Nietzsche",
        "category": "Philosophy"
    }, {
        "text": "And those who were seen dancing were thought to be insane by those who could not hear the music.",
        "author": "Friedrich Nietzsche",
        "category": "Philosophy"
    }, {
        "text": "My grief counselor died. He was so good, I don’t even care.",
        "author": "Gary Delaney",
        "category": "Humor"
    }, {
        "text": "Even people who are good for nothing have the capacity to bring a smile to your face, for instance when you push them down the stairs.",
        "author": "Anonymous",
        "category": "Humor"
    }, {
        "text": "I’ll never forget my Granddad’s last words to me just before he died. 'Are you still holding the ladder?'",
        "author": "Anonymous",
        "category": "Humor"
    }, {
        "text": "I was playing chess with my friend and he said, 'Let's make this interesting'. So we stopped playing chess.",
        "author": "Matt Kirshen",
        "category": "Humor"
    }]
    property var currentQuote

    function getCategories() {
        for (let i = 0; i < quotes.length; i++) {
            if (!categories.includes(quotes[i].category))
                categories.push(quotes[i].category);

        }
    }

    function generateRandomQuote() {
        let arr = [];
        for (let i = 0; i < quotes.length; i++) {
            if (currentCategory === "All" || quotes[i].category === currentCategory)
                arr.push(quotes[i]);

        }
        if (arr.length === 0)
            return ;

        if (arr.length === 1) {
            currentQuote = arr[0];
            return ;
        }
        let randomIndex = Math.floor(Math.random() * arr.length);
        let selectedQuote = arr[randomIndex];
        while (currentQuote && selectedQuote.text === currentQuote.text) {
            randomIndex = Math.floor(Math.random() * arr.length);
            selectedQuote = arr[randomIndex];
        }
        currentQuote = selectedQuote;
    }

    Component.onCompleted: {
        getCategories();
        generateRandomQuote();
    }
    onCurrentCategoryChanged: {
        generateRandomQuote();
    }
}
