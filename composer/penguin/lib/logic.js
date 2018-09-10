/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * Track the trade of a penguin from one collector to another
 * @param {org.collectable.penguin.Trade} trade - the trade to be processed
 * @transaction
 */
function tradePenguin(trade) {

    // set the new owner of the commodity
    trade.penguin.owner = trade.newOwner;
    return getAssetRegistry('org.collectable.penguin.Penguin')
        .then(function (assetRegistry) {

            // emit a notification that a trade has occurred
            var tradeNotification = getFactory().newEvent('org.collectable.penguin', 'TradeNotification');
            tradeNotification.penguin = trade.penguin;
            tradeNotification.newOwner = trade.newOwner;
            emit(tradeNotification);

            // persist the state of the commodity
            return assetRegistry.update(trade.penguin);
        });
}

/**
 * Creates some assets
 * @param {org.collectable.penguin._demoSetup} demo - demoSetup
 * @transaction
 */
function setup() {
    var factory = getFactory();
    var NS = 'org.collectable.penguin';
    var collectors = [
        factory.newResource(NS, 'Collector', 'CAROLINE'),
        factory.newResource(NS, 'Collector', 'TRACY'),
        factory.newResource(NS, 'Collector', 'TOM'),
        factory.newResource(NS, 'Collector', 'WHOLESALER')
    ];


    var penguins = [
        factory.newResource(NS, 'Penguin', 'Pingu'),
        factory.newResource(NS, 'Penguin', 'Pinga'),
        factory.newResource(NS, 'Penguin', 'Pingo'),
        factory.newResource(NS, 'Penguin', 'Pongy'),
        factory.newResource(NS, 'Penguin', 'Punki')
    ];

    /* add the resource and the traders */
    return getParticipantRegistry(NS + '.Collector')
        .then(function (collectorRegistry) {
            collectors.forEach(function (collector) {

                collector.firstName = collector.getIdentifier().toLowerCase();
                collector.lastName = 'Collector';
            });
            return collectorRegistry.addAll(collectors);
        })
        .then(function () {
            return getAssetRegistry(NS + '.Penguin');
        })
        .then(function (assetRegistry) {
            penguins.forEach(function (penguin) {
                penguin.description = 'My name is ' + penguin.getIdentifier();
                penguin.owner = factory.newRelationship(NS, 'Collector', 'WHOLESALER');
            });
            return assetRegistry.addAll(penguins);
        });
}
