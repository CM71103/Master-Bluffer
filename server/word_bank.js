// Curated pairs: both words in a pair belong to the same category.
// randomWordPair() draws from these without repeating a pair until the whole
// category has been used, so a session does not see the same words twice in a row.
const WORD_BANK = Object.freeze({
  foods: [
    ['Cake', 'Pastry'], ['Pizza', 'Calzone'], ['Burger', 'Sandwich'],
    ['Pasta', 'Noodles'], ['Pancake', 'Waffle'], ['Ice Cream', 'Gelato'],
    ['Cookie', 'Brownie'], ['Soup', 'Stew'], ['Taco', 'Burrito'],
    ['Donut', 'Muffin'], ['Croissant', 'Bagel'], ['Sushi', 'Sashimi'],
    ['Steak', 'Ribs'], ['Salad', 'Coleslaw'], ['Cereal', 'Granola'],
    ['Curry', 'Casserole'], ['Pie', 'Tart'], ['Chocolate', 'Caramel'],
    ['Smoothie', 'Milkshake'], ['Lasagna', 'Ravioli'], ['Popcorn', 'Chips'],
    ['Jam', 'Jelly'],
  ],
  football: [
    ['Goalkeeper', 'Defender'], ['Striker', 'Winger'], ['Penalty', 'Free Kick'],
    ['Corner Kick', 'Throw-in'], ['Yellow Card', 'Red Card'],
    ['Stadium', 'Pitch'], ['Crossbar', 'Goalpost'], ['Referee', 'Linesman'],
    ['Dribble', 'Pass'], ['Header', 'Volley'], ['Cleats', 'Shin Guards'],
    ['Captain', 'Coach'], ['Midfielder', 'Forward'], ['Offside', 'Handball'],
    ['Tackle', 'Foul'], ['Kick-off', 'Half-time'], ['Boot', 'Glove'],
    ['Pitch', 'Turf'], ['Whistle', 'Flag'], ['Substitute', 'Bench'],
    ['Formation', 'Tactic'], ['League', 'Cup'],
  ],
  animals: [
    ['Lion', 'Tiger'], ['Wolf', 'Fox'], ['Dolphin', 'Whale'],
    ['Eagle', 'Hawk'], ['Horse', 'Donkey'], ['Crocodile', 'Alligator'],
    ['Butterfly', 'Moth'], ['Bee', 'Wasp'], ['Frog', 'Toad'],
    ['Rabbit', 'Hare'], ['Turtle', 'Tortoise'], ['Seal', 'Sea Lion'],
    ['Leopard', 'Cheetah'], ['Bear', 'Panda'], ['Owl', 'Bat'],
    ['Shark', 'Orca'], ['Camel', 'Llama'], ['Penguin', 'Puffin'],
    ['Snake', 'Lizard'], ['Goat', 'Sheep'], ['Parrot', 'Crow'],
    ['Ant', 'Termite'],
  ],
  places: [
    ['Beach', 'Island'], ['Mountain', 'Hill'], ['Library', 'Bookshop'],
    ['Museum', 'Gallery'], ['Park', 'Garden'], ['Cafe', 'Restaurant'],
    ['Airport', 'Train Station'], ['Hotel', 'Hostel'], ['Lake', 'Pond'],
    ['Castle', 'Palace'], ['Forest', 'Jungle'], ['Cinema', 'Theatre'],
    ['School', 'University'], ['Hospital', 'Clinic'], ['Bank', 'ATM'],
    ['Zoo', 'Aquarium'], ['Bakery', 'Butcher'], ['Market', 'Mall'],
    ['Bridge', 'Tunnel'], ['Desert', 'Canyon'], ['Village', 'Town'],
    ['Gym', 'Studio'],
  ],
});

const DEFAULT_CATEGORY = 'foods';
const CATEGORIES = Object.freeze(Object.keys(WORD_BANK));

module.exports = { WORD_BANK, CATEGORIES, DEFAULT_CATEGORY };
