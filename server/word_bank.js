// Curated pairs: both words in a pair belong to the same category.
const WORD_BANK = Object.freeze({
  foods: [
    ['Cake', 'Pastry'], ['Pizza', 'Calzone'], ['Burger', 'Sandwich'],
    ['Pasta', 'Noodles'], ['Pancake', 'Waffle'], ['Ice Cream', 'Gelato'],
    ['Cookie', 'Brownie'], ['Soup', 'Stew'], ['Taco', 'Burrito'],
    ['Donut', 'Muffin'], ['Croissant', 'Bagel'], ['Sushi', 'Sashimi'],
  ],
  football: [
    ['Goalkeeper', 'Defender'], ['Striker', 'Winger'], ['Penalty', 'Free Kick'],
    ['Corner Kick', 'Throw-in'], ['Yellow Card', 'Red Card'],
    ['Stadium', 'Pitch'], ['Crossbar', 'Goalpost'], ['Referee', 'Linesman'],
    ['Dribble', 'Pass'], ['Header', 'Volley'], ['Cleats', 'Shin Guards'],
    ['Captain', 'Coach'],
  ],
  animals: [
    ['Lion', 'Tiger'], ['Wolf', 'Fox'], ['Dolphin', 'Whale'],
    ['Eagle', 'Hawk'], ['Horse', 'Donkey'], ['Crocodile', 'Alligator'],
    ['Butterfly', 'Moth'], ['Bee', 'Wasp'], ['Frog', 'Toad'],
    ['Rabbit', 'Hare'], ['Turtle', 'Tortoise'], ['Seal', 'Sea Lion'],
  ],
  places: [
    ['Beach', 'Island'], ['Mountain', 'Hill'], ['Library', 'Bookshop'],
    ['Museum', 'Gallery'], ['Park', 'Garden'], ['Cafe', 'Restaurant'],
    ['Airport', 'Train Station'], ['Hotel', 'Hostel'], ['Lake', 'Pond'],
    ['Castle', 'Palace'], ['Forest', 'Jungle'], ['Cinema', 'Theatre'],
  ],
});

const DEFAULT_CATEGORY = 'foods';
const CATEGORIES = Object.freeze(Object.keys(WORD_BANK));

module.exports = { WORD_BANK, CATEGORIES, DEFAULT_CATEGORY };
