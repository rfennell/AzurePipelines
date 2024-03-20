module.exports = {
  reporters: [
    'default',
    [
      'jest-junit',
      {
        outputFile: 'test-output/test-results.xml'
      },
    ],
  ],
  testMatch: [
    '<rootDir>/dist/test/*.test.js'
  ]
}