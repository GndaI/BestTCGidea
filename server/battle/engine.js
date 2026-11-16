"use strict";

const { createBattleState } = require("./state");
const { createSnapshot } = require("./snapshot");
const turn = require("./turn");

class BattleEngine {
  constructor(decks, options = {}) {
    this.state = createBattleState(decks, options);
  }

  start() {
    return this.#transition(() => turn.startNextTurn(this.state));
  }

  completeProduction() {
    return this.#transition(() => turn.completeProduction(this.state));
  }

  completeReveal() {
    return this.#transition(() => turn.completeReveal(this.state));
  }

  requestTurnEnd(playerIndex) {
    return this.#transition(() => turn.requestTurnEnd(this.state, playerIndex));
  }

  completeTurn() {
    return this.#transition(() => turn.completeTurn(this.state));
  }

  startNextTurn() {
    return this.#transition(() => turn.startNextTurn(this.state));
  }

  snapshot() {
    return createSnapshot(this.state);
  }

  #transition(operation) {
    const result = operation();
    return { ...result, snapshot: this.snapshot() };
  }
}

module.exports = { BattleEngine };
