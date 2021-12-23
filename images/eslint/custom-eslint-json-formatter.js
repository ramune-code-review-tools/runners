// @see https://eslint.org/docs/developer-guide/working-with-custom-formatters
module.exports = (results, data) => {
  const meta = data ? data.rulesMeta : null;

  const docs = ruleId => {
    if (meta && meta[ruleId] && meta[ruleId].docs) {
      const { recommended, url } = meta[ruleId].docs;
      return { recommended, url };
    } else {
      return null;
    }
  };

  const newResults = results.map(({ filePath, messages }) => ({
    filePath,

    messages: messages.map(
      ({ ruleId, severity, message, line, column, endLine, endColumn }) => ({
        ruleId,
        severity,
        message,
        line,
        column,
        endLine,
        endColumn,
        docs: docs(ruleId)
      })
    )
  }));

  return JSON.stringify(newResults);
};
