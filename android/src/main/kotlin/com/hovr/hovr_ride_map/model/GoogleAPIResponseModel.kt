package com.hovr.hovr_ride_map.model

// Main response wrapper - simplified to match actual JSON
data class ComputeRoutesResponse(
    val distanceMeters: String,
    val durationSeconds: String,
    val polyline: String,
    val provider: String,
    // Keep calculation results for backward compatibility
    val calculationResults: CalculationResults? = null
)

// Alternative if you want to keep route structure but simplified
data class RouteResponse(
    val route: SimpleRoute,
    val calculationResults: CalculationResults? = null
)

data class SimpleRoute(
    val distanceMeters: String,
    val durationSeconds: String,
    val polyline: String,
    val provider: String
)

// Simplified location
data class Location(
    val latitude: Double,
    val longitude: Double,
    val address: String? = null
)

// Keep existing pricing models unchanged
data class ServiceResult(
    val service: Service,
    val calculationResults: CalculationResults
)

data class CalculationResults(
    val distanceAmount: DistanceAmount,
    val timeAmount: DistanceAmount,
    val insuranceAmount: DistanceAmount,
    val cityFee: Fee,
    val infrastructureFee: Fee,
    val hovrFee: HovrFee,
    val tax: DistanceAmount,
    val totalAmountBeforeTax: DistanceAmount,
    val totalAmountAfterTax: DistanceAmount,
    val totalProcessingFee: Fee,
    val taxOnFee: Fee
)

data class Fee(
    val currencyCode: CurrencyCode,
    val nanos: Long
)

enum class CurrencyCode {
    CAD, USD, INR // Added more currencies
}

data class DistanceAmount(
    val currencyCode: CurrencyCode,
    val units: String,
    val nanos: Long
)

data class HovrFee(
    val currencyCode: CurrencyCode,
    val units: String
)

data class Service(
    val serviceName: String,
    val status: String,
    val minSeats: Long,
    val maxSeats: Long
)


//data class ComputeRoutesResponse(
//    val routes: List<Route>,
//    val geocodingResults: GeocodingResults
//)
//
//class GeocodingResults()
//
//data class Route(
//    val legs: List<Leg>,
//    val distanceMeters: Long,
//    val duration: String,
//    val staticDuration: String,
//    val polyline: Polyline,
//    val description: String,
//    val warnings: List<String>,
//    val viewport: Viewport,
//    val travelAdvisory: GeocodingResults,
//    val routeToken: String
//)
//
//data class Leg(
//    val distanceMeters: Long,
//    val duration: String,
//    val staticDuration: String,
//    val polyline: Polyline,
//    val startLocation: GeocodingResults,
//    val endLocation: GeocodingResults,
//    val steps: List<Step>
//)
//
//data class Polyline(
//    val encodedPolyline: String
//)
//
//data class Step(
//    val distanceMeters: Long,
//    val staticDuration: String,
//    val polyline: Polyline,
//    val startLocation: GeocodingResults,
//    val endLocation: GeocodingResults
//)
//
//data class Viewport(
//    val low: High,
//    val high: High
//)
//
//data class High(
//    val latitude: Double,
//    val longitude: Double
//)
//
//data class ServiceResult(
//    val service: Service,
//    val calculationResults: CalculationResults
//)
//
//data class CalculationResults(
//    val distanceAmount: DistanceAmount,
//    val timeAmount: DistanceAmount,
//    val insuranceAmount: DistanceAmount,
//    val cityFee: Fee,
//    val infrastructureFee: Fee,
//    val hovrFee: HovrFee,
//    val tax: DistanceAmount,
//    val totalAmountBeforeTax: DistanceAmount,
//    val totalAmountAfterTax: DistanceAmount,
//    val totalProcessingFee: Fee,
//    val taxOnFee: Fee
//)
//
//data class Fee(
//    val currencyCode: CurrencyCode,
//    val nanos: Long
//)
//
//enum class CurrencyCode {
//    CAD
//}
//
//data class DistanceAmount(
//    val currencyCode: CurrencyCode,
//    val units: String,
//    val nanos: Long
//)
//
//data class HovrFee(
//    val currencyCode: CurrencyCode,
//    val units: String
//)
//
//data class Service(
//    val serviceName: String,
//    val status: String,
//    val minSeats: Long,
//    val maxSeats: Long
//)
