import { describe, it, expect } from 'vitest'
import { calculateDistance, formatDistance } from './geo'

describe('geo utils', () => {
  it('calculates distance between two points', () => {
    const lat1 = 7.1139
    const lon1 = -73.1198
    const lat2 = 7.1139
    const lon2 = -73.1198
    expect(calculateDistance(lat1, lon1, lat2, lon2)).toBe(0)
  })

  it('formats distance correctly', () => {
    expect(formatDistance(500)).toBe('500 m')
    expect(formatDistance(1500)).toBe('1.5 km')
  })
})
