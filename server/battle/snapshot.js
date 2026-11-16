"use strict";

const { cloneJson } = require("./state");

function createSnapshot(state) {
  return cloneJson(state);
}

module.exports = { createSnapshot };
