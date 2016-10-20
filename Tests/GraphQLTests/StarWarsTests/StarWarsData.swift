/**
 * This defines a basic set of data for our Star Wars Schema.
 *
 * This data is hard coded for the sake of the demo, but you could imagine
 * fetching this data from a backend service rather than from hardcoded
 * values in a more complex demo.
 */

enum Episode : String {
    case newHope = "NEWHOPE"
    case empire = "EMPIRE"
    case jedi = "JEDI"
}

protocol Character {
    var id: String { get }
    var name: String { get }
    var friends: [String] { get }
    var appearsIn: [Episode] { get }
}

struct Human : Character {
    let id: String
    let name: String
    let friends: [String]
    let appearsIn: [Episode]
    let homePlanet: String?

    init(id: String, name: String, friends: [String], appearsIn: [Episode], homePlanet: String? = nil) {
        self.id = id
        self.name = name
        self.friends = friends
        self.appearsIn = appearsIn
        self.homePlanet = homePlanet
    }
}

struct Droid : Character {
    let id: String
    let name: String
    let friends: [String]
    let appearsIn: [Episode]
    let primaryFunction: String
}

let luke = Human(
    id: "1000",
    name: "Luke Skywalker",
    friends: ["1002", "1003", "2000", "2001"],
    appearsIn: [.newHope, .empire, .jedi],
    homePlanet: "Tatooine"
)

let vader = Human(
    id: "1001",
    name: "Darth Vader",
    friends: [ "1004" ],
    appearsIn: [.newHope, .empire, .jedi],
    homePlanet: "Tatooine"
)

let han = Human(
    id: "1002",
    name: "Han Solo",
    friends: ["1000", "1003", "2001"],
    appearsIn: [.newHope, .empire, .jedi]
)

let leia = Human(
    id: "1003",
    name: "Leia Organa",
    friends: ["1000", "1002", "2000", "2001"],
    appearsIn: [.newHope, .empire, .jedi],
    homePlanet: "Alderaan"
)

let tarkin = Human(
    id: "1004",
    name: "Wilhuff Tarkin",
    friends: ["1001"],
    appearsIn: [.newHope]
)

let humanData: [String: Human] = [
    "1000": luke,
    "1001": vader,
    "1002": han,
    "1003": leia,
    "1004": tarkin,
]

let threepio = Droid(
    id: "2000",
    name: "C-3PO",
    friends: ["1000", "1002", "1003", "2001"],
    appearsIn: [.newHope, .empire, .jedi],
    primaryFunction: "Protocol"
)

let artoo = Droid(
    id: "2001",
    name: "R2-D2",
    friends: [ "1000", "1002", "1003" ],
    appearsIn: [.newHope, .empire, .jedi],
    primaryFunction: "Astromech"
)

let droidData: [String: Droid] = [
    "2000": threepio,
    "2001": artoo,
]

/**
 * Helper function to get a character by ID.
 */
func getCharacter(id: String) -> Character? {
    return humanData[id] ?? droidData[id]
}

/**
 * Allows us to query for a character"s friends.
 */
func getFriends(character: Character) -> [Character] {
    return character.friends.reduce([]) { friends, friendID in
        var friends = friends
        guard let friend = getCharacter(id: friendID) else {
            return friends
        }
        friends.append(friend)
        return friends
    }
}

/**
 * Allows us to fetch the undisputed hero of the Star Wars trilogy, R2-D2.
 */
func getHero(episode: Episode?) -> Character {
    if episode == .empire {
        // Luke is the hero of Episode V.
        return luke
    }
    // Artoo is the hero otherwise.
    return artoo
}

/**
 * Allows us to query for the human with the given id.
 */
func getHuman(id: String) -> Human? {
    return humanData[id]
}

/**
 * Allows us to query for the droid with the given id.
 */
func getDroid(id: String) -> Droid? {
    return droidData[id]
}
