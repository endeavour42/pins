# pins
stream of pins on the world map

- note that you need to provide your token to compile and run the app.
- tests don't rely on the token/network, so they can be run with any string in the token.
- works on ios/mac, super easy to port to watch and tv.
- under xcode 13+, ios15+, macOS12+ shows last few user avatars
- old pins are not removed as time goes by (i.e. accumulating), they are removed on a new search string
- see the big comment near "didReceive data", that would be the first thing to fix in the real production app.
