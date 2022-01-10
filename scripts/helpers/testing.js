function assert(condition, message) {
    if (!condition) {
        throw message || "Assertion failed";
    }
}

module.exports = {
    assert,
}