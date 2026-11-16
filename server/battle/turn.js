"use strict";

const { MATCH_STATUS, appendEvent } = require("./state");

const TURN_PHASE = Object.freeze({
  IDLE: "idle",
  PRODUCTION: "production",
  REVEAL: "reveal",
  ACTION: "action",
  END: "end",
  COMPLETE: "complete",
});

function accepted(event = null) {
  return { ok: true, event };
}

function rejected(code) {
  return { ok: false, code };
}

function activePlayerForTurn(turnIndex) {
  if (!Number.isInteger(turnIndex) || turnIndex < 0) {
    throw new RangeError("turnIndex must be a non-negative integer.");
  }
  if (turnIndex < 12) return [0, 1, 1, 0][turnIndex % 4];
  return turnIndex % 2 === 0 ? 1 : 0;
}

function resetTurnUsage(state) {
  for (const player of state.players) {
    for (const unit of player.units) {
      unit.usedThisTurn = false;
      unit.usedThisChain = false;
    }
  }
}

function startNextTurn(state) {
  if (state.status === MATCH_STATUS.OVER) return rejected("battle_over");
  if (![TURN_PHASE.IDLE, TURN_PHASE.COMPLETE].includes(state.phase)) {
    return rejected("turn_already_active");
  }

  state.status = MATCH_STATUS.PLAYING;
  state.turnIndex += 1;
  state.activePlayer = activePlayerForTurn(state.turnIndex);
  state.priorityPlayer = state.activePlayer;
  state.players[state.activePlayer].ownTurns += 1;
  state.phase = TURN_PHASE.PRODUCTION;
  state.passes = 0;
  state.ending = false;
  resetTurnUsage(state);

  return accepted(appendEvent(state, "turn_started", {
    turnIndex: state.turnIndex,
    activePlayer: state.activePlayer,
    ownTurn: state.players[state.activePlayer].ownTurns,
  }));
}

function completeProduction(state) {
  if (state.phase !== TURN_PHASE.PRODUCTION) return rejected("not_in_production");
  const player = state.players[state.activePlayer];
  state.phase = player.revealed < 6 ? TURN_PHASE.REVEAL : TURN_PHASE.ACTION;
  return accepted(appendEvent(state, "production_completed", {
    activePlayer: state.activePlayer,
    nextPhase: state.phase,
  }));
}

function completeReveal(state) {
  if (state.phase !== TURN_PHASE.REVEAL) return rejected("not_in_reveal");
  const player = state.players[state.activePlayer];
  if (player.revealed >= 6) return rejected("all_stages_revealed");
  player.revealed += 1;
  state.phase = TURN_PHASE.ACTION;
  return accepted(appendEvent(state, "reveal_completed", {
    activePlayer: state.activePlayer,
    revealed: player.revealed,
  }));
}

function requestTurnEnd(state, playerIndex) {
  if (state.phase !== TURN_PHASE.ACTION) return rejected("not_in_action");
  if (playerIndex !== state.activePlayer || playerIndex !== state.priorityPlayer) {
    return rejected("not_turn_owner");
  }
  state.phase = TURN_PHASE.END;
  state.ending = true;
  return accepted(appendEvent(state, "turn_end_requested", {
    activePlayer: state.activePlayer,
  }));
}

function completeTurn(state) {
  if (state.phase !== TURN_PHASE.END) return rejected("not_in_turn_end");
  state.phase = TURN_PHASE.COMPLETE;
  state.priorityPlayer = null;
  state.ending = false;
  return accepted(appendEvent(state, "turn_completed", {
    turnIndex: state.turnIndex,
    activePlayer: state.activePlayer,
  }));
}

module.exports = {
  TURN_PHASE,
  activePlayerForTurn,
  completeProduction,
  completeReveal,
  completeTurn,
  requestTurnEnd,
  startNextTurn,
};
