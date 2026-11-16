"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { BattleEngine } = require("../battle/engine");
const { TURN_PHASE, activePlayerForTurn } = require("../battle/turn");

function emptyDeck() {
  return Array.from({ length: 6 }, () => ["left", "right"]);
}

test("the opening twelve turns and later alternation match the current rule", () => {
  const order = Array.from({ length: 20 }, (_, index) => activePlayerForTurn(index));
  assert.deepEqual(order, [0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]);
});

test("one turn advances through production, reveal, action, end, and complete", () => {
  const engine = new BattleEngine([emptyDeck(), emptyDeck()]);

  assert.equal(engine.start().ok, true);
  assert.equal(engine.state.turnIndex, 0);
  assert.equal(engine.state.activePlayer, 0);
  assert.equal(engine.state.players[0].ownTurns, 1);
  assert.equal(engine.state.phase, TURN_PHASE.PRODUCTION);

  assert.equal(engine.completeProduction().ok, true);
  assert.equal(engine.state.phase, TURN_PHASE.REVEAL);
  assert.equal(engine.completeReveal().ok, true);
  assert.equal(engine.state.players[0].revealed, 1);
  assert.equal(engine.state.phase, TURN_PHASE.ACTION);

  assert.deepEqual(engine.requestTurnEnd(1), {
    ok: false,
    code: "not_turn_owner",
    snapshot: engine.snapshot(),
  });
  assert.equal(engine.requestTurnEnd(0).ok, true);
  assert.equal(engine.state.phase, TURN_PHASE.END);
  assert.equal(engine.completeTurn().ok, true);
  assert.equal(engine.state.phase, TURN_PHASE.COMPLETE);
});

test("a new turn resets per-turn and per-chain unit usage", () => {
  const engine = new BattleEngine([emptyDeck(), emptyDeck()]);
  engine.state.players[0].units.push({ usedThisTurn: true, usedThisChain: true });
  engine.state.players[1].units.push({ usedThisTurn: true, usedThisChain: true });

  engine.start();

  for (const player of engine.state.players) {
    assert.equal(player.units[0].usedThisTurn, false);
    assert.equal(player.units[0].usedThisChain, false);
  }
});

test("reveal is skipped after a player has revealed all six stages", () => {
  const engine = new BattleEngine([emptyDeck(), emptyDeck()]);
  engine.state.players[0].revealed = 6;

  engine.start();
  assert.equal(engine.completeProduction().ok, true);
  assert.equal(engine.state.phase, TURN_PHASE.ACTION);
  assert.equal(engine.completeReveal().code, "not_in_reveal");
});

test("invalid phase transitions do not advance the turn", () => {
  const engine = new BattleEngine([emptyDeck(), emptyDeck()]);
  assert.equal(engine.completeProduction().code, "not_in_production");
  assert.equal(engine.requestTurnEnd(0).code, "not_in_action");
  assert.equal(engine.state.turnIndex, -1);
  assert.equal(engine.state.phase, TURN_PHASE.IDLE);
});

test("snapshots are JSON-safe copies rather than the mutable server state", () => {
  const engine = new BattleEngine([emptyDeck(), emptyDeck()]);
  engine.start();
  const snapshot = engine.snapshot();

  assert.doesNotThrow(() => JSON.stringify(snapshot));
  snapshot.players[0].ownTurns = 999;
  assert.equal(engine.state.players[0].ownTurns, 1);
});
