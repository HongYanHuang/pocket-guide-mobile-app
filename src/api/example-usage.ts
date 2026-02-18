/**
 * Example usage of the auto-generated API client
 *
 * This file demonstrates how to use the type-safe API client
 * generated from the OpenAPI specification using swagger-typescript-api.
 *
 * NO JAVA REQUIRED! 🎉
 */

import { HttpClient } from './generated/http-client'
import { Tour } from './generated/Tour'
import { Tours } from './generated/Tours'
import { Pois } from './generated/Pois'
import { ComboTickets } from './generated/ComboTickets'
import type { TourGenerationRequest } from './generated/data-contracts'

// =============================================================================
// Configuration
// =============================================================================

const API_BASE_URL = process.env.NODE_ENV === 'development'
  ? 'http://localhost:8000'  // Development
  : 'https://api.pocket-guide.com'  // Production

// Create HTTP client
const httpClient = new HttpClient({
  baseURL: API_BASE_URL,
  // Add authentication headers if needed
  // headers: {
  //   'Authorization': `Bearer ${authToken}`
  // }
})

// Create API instances
const tourApi = new Tour(httpClient)
const toursApi = new Tours(httpClient)
const poisApi = new Pois(httpClient)
const comboTicketsApi = new ComboTickets(httpClient)

// =============================================================================
// Tour Generation Example
// =============================================================================

export async function generateTour(params: {
  city: string
  days: number
  interests: string[]
  pace?: 'relaxed' | 'normal' | 'packed'
  language?: string
  startLocation?: string
  endLocation?: string
}) {
  try {
    const request: TourGenerationRequest = {
      city: params.city,
      days: params.days,
      interests: params.interests,
      provider: 'anthropic',
      pace: params.pace || 'normal',
      walking: 'moderate',
      language: params.language || 'en',
      mode: 'simple',
      save: true,
      start_location: params.startLocation,
      end_location: params.endLocation,
    }

    const response = await tourApi.generateTourTourGeneratePost(request)

    console.log('✅ Tour generated:', response.data.tour_id)
    return response.data
  } catch (error) {
    console.error('❌ Failed to generate tour:', error)
    throw error
  }
}

// =============================================================================
// Tour Management Examples
// =============================================================================

export async function getTourById(tourId: string) {
  try {
    const response = await toursApi.getTourDetailToursTourIdGet(tourId)
    return response.data
  } catch (error) {
    console.error(`❌ Failed to get tour ${tourId}:`, error)
    throw error
  }
}

export async function listTours(city?: string, limit: number = 20) {
  try {
    const response = await toursApi.listToursToursGet({
      city,
      limit,
      offset: 0
    })
    return response.data
  } catch (error) {
    console.error('❌ Failed to list tours:', error)
    throw error
  }
}

export async function replacePOI(
  tourId: string,
  originalPOI: string,
  replacementPOI: string,
  language: string = 'en'
) {
  try {
    const response = await toursApi.replaceTourPoiToursTourIdReplacePoiPost(
      tourId,
      {
        original_poi: originalPOI,
        replacement_poi: replacementPOI,
        mode: 'simple',
        language: language
      }
    )

    console.log('✅ POI replaced successfully')
    return response.data
  } catch (error) {
    console.error('❌ Failed to replace POI:', error)
    throw error
  }
}

export async function replacePOIsBatch(
  tourId: string,
  replacements: Array<{
    original_poi: string
    replacement_poi: string
    day: number
  }>,
  language: string = 'en'
) {
  try {
    const response = await toursApi.replaceTourPoisBatchToursTourIdReplacePoisBatchPost(
      tourId,
      {
        replacements,
        mode: 'simple',
        language
      }
    )

    console.log('✅ POIs replaced successfully')
    return response.data
  } catch (error) {
    console.error('❌ Failed to replace POIs:', error)
    throw error
  }
}

// =============================================================================
// POI Information Examples
// =============================================================================

export async function getCityPOIs(city: string) {
  try {
    const response = await poisApi.listCityPoisPoisCityGet(city)
    return response.data
  } catch (error) {
    console.error(`❌ Failed to get POIs for ${city}:`, error)
    throw error
  }
}

export async function getPOIDetails(city: string, poiId: string) {
  try {
    const response = await poisApi.getPoiDetailsPoisCityPoiIdGet(city, poiId)
    return response.data
  } catch (error) {
    console.error(`❌ Failed to get POI details for ${poiId}:`, error)
    throw error
  }
}

export async function getPOITranscript(
  city: string,
  poiId: string,
  language: string = 'en',
  tourId?: string
) {
  try {
    const response = await poisApi.getPoiTranscriptPoisCityPoiIdTranscriptGet({
      city,
      poiId,
      language,
      tourId
    })
    return response.data
  } catch (error) {
    console.error(`❌ Failed to get transcript for ${poiId}:`, error)
    throw error
  }
}

// =============================================================================
// Combo Tickets Examples
// =============================================================================

export async function getComboTickets(city: string) {
  try {
    const response = await comboTicketsApi.listComboTicketsComboTicketsCityGet(city)
    return response.data
  } catch (error) {
    console.error(`❌ Failed to get combo tickets for ${city}:`, error)
    throw error
  }
}

export async function getComboTicketById(city: string, ticketId: string) {
  try {
    const response = await comboTicketsApi.getComboTicketComboTicketsCityTicketIdGet(
      city,
      ticketId
    )
    return response.data
  } catch (error) {
    console.error(`❌ Failed to get combo ticket ${ticketId}:`, error)
    throw error
  }
}

// =============================================================================
// React Native Hooks Examples
// =============================================================================

import { useState, useCallback } from 'react'

/**
 * Custom hook for tour generation
 *
 * Usage:
 * ```typescript
 * const { generateTour, loading, error } = useGenerateTour()
 *
 * const handleGenerate = async () => {
 *   const tour = await generateTour({
 *     city: 'rome',
 *     days: 3,
 *     interests: ['history']
 *   })
 * }
 * ```
 */
export function useGenerateTour() {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const generate = useCallback(async (params: Parameters<typeof generateTour>[0]) => {
    setLoading(true)
    setError(null)

    try {
      const result = await generateTour(params)
      return result
    } catch (err) {
      setError(err as Error)
      throw err
    } finally {
      setLoading(false)
    }
  }, [])

  return { generateTour: generate, loading, error }
}

/**
 * Custom hook for fetching tours
 *
 * Usage:
 * ```typescript
 * const { tours, loading, error, refetch } = useTours('rome')
 * ```
 */
export function useTours(city?: string, limit: number = 20) {
  const [tours, setTours] = useState<any[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  const fetchTours = useCallback(async () => {
    setLoading(true)
    setError(null)

    try {
      const result = await listTours(city, limit)
      setTours(result.tours || [])
      return result
    } catch (err) {
      setError(err as Error)
      throw err
    } finally {
      setLoading(false)
    }
  }, [city, limit])

  return { tours, loading, error, refetch: fetchTours }
}

// =============================================================================
// TypeScript Type Examples
// =============================================================================

/**
 * The generated client provides full TypeScript types.
 *
 * Import types from data-contracts:
 *
 * ```typescript
 * import {
 *   TourResponse,
 *   TourGenerationRequest,
 *   POIDetail,
 *   ComboTicket,
 *   DayItinerary
 * } from './generated/data-contracts'
 *
 * // Use them in your components:
 * const [tour, setTour] = useState<TourResponse | null>(null)
 * const [pois, setPOIs] = useState<POIDetail[]>([])
 * ```
 */

// =============================================================================
// Error Handling Example
// =============================================================================

export async function safeApiCall<T>(
  apiCall: () => Promise<T>
): Promise<{ data?: T; error?: Error }> {
  try {
    const data = await apiCall()
    return { data }
  } catch (error) {
    console.error('API Error:', error)
    return { error: error as Error }
  }
}

// Usage example:
// const { data, error } = await safeApiCall(() => getTourById('tour-123'))
// if (error) { /* handle error */ }
// if (data) { /* use data */ }
