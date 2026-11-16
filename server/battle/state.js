"use strict";

const MATCH_STATUS = Object.freeze({
  READY: "ready",
  PLAYING: "playing",
  OVER: "over",
});

function cloneJson(value) {
  return JSON.parse(JSON.stringify(value));
}

function createPlayerState(deck) {
  return {
    deck: cloneJson(deck),
    units: [],
    spellHand: [],
    usedSpells: [],
    revealed: 0,
    ownTurns: 0,
  };
}

function createBattleState(decks, options = {}) {
  if (!Array.isArray(decks) || decks.length !== 2 || decks.some((deck) => !Array.isArray(deck))) {
    throw new TypeError("A battle requires exactly two decks.");
  }

  return {
    version: 1,
    mode: String(options.mode || "standard"),
    status: MATCH_STATUS.READY,
    turnIndex: -1,
    activePlayer: null,
    priorityPlayer: null,
    phase: "idle",
    passes: 0,
    ending: false,
    players: decks.map(createPlayerState),
    events: [],
    nextEventId: 1,
  };
}

function appendEvent(state, type, data = {}) {
  const event = {
    id: state.nextEventId,
    type,
    ...cloneJson(data),
  };
  state.nextEventId += 1;
  state.events.push(event);
  return event;
}

module.exports = {
  MATCH_STATUS,
  appendEvent,
  cloneJson,
  createBattleState,
};
