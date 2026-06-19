package com.viralvaghela.movenow

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class DatabaseHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_NAME = "movenow_background.db"
        private const val DATABASE_VERSION = 1

        // Events Table
        const val TABLE_EVENTS = "history_events"
        const val COL_EVENT_ID = "id"
        const val COL_EVENT_TYPE = "type" // 'walk', 'inactivity', 'alarm_trigger', 'alarm_dismiss'
        const val COL_EVENT_TIMESTAMP = "timestamp"
        const val COL_EVENT_DURATION = "duration_seconds"
        const val COL_EVENT_STEPS = "steps"
        const val COL_EVENT_DISTANCE = "distance"
        const val COL_EVENT_DETAILS = "details"

        // Hourly Steps Table
        const val TABLE_HOURLY = "hourly_steps"
        const val COL_HOURLY_ID = "id"
        const val COL_HOURLY_DATE_HOUR = "date_hour" // "yyyy-MM-dd HH"
        const val COL_HOURLY_STEPS = "steps"
        const val COL_HOURLY_DISTANCE = "distance"
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createEventsTable = """
            CREATE TABLE $TABLE_EVENTS (
                $COL_EVENT_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COL_EVENT_TYPE TEXT,
                $COL_EVENT_TIMESTAMP INTEGER,
                $COL_EVENT_DURATION INTEGER,
                $COL_EVENT_STEPS INTEGER,
                $COL_EVENT_DISTANCE REAL,
                $COL_EVENT_DETAILS TEXT
            )
        """.trimIndent()

        val createHourlyTable = """
            CREATE TABLE $TABLE_HOURLY (
                $COL_HOURLY_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COL_HOURLY_DATE_HOUR TEXT UNIQUE,
                $COL_HOURLY_STEPS INTEGER,
                $COL_HOURLY_DISTANCE REAL
            )
        """.trimIndent()

        db.execSQL(createEventsTable)
        db.execSQL(createHourlyTable)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE_EVENTS")
        db.execSQL("DROP TABLE IF EXISTS $TABLE_HOURLY")
        onCreate(db)
    }

    fun insertEvent(type: String, durationSeconds: Int, steps: Int, distance: Double, details: String): Long {
        val db = this.writableDatabase
        val values = ContentValues().apply {
            put(COL_EVENT_TYPE, type)
            put(COL_EVENT_TIMESTAMP, System.currentTimeMillis())
            put(COL_EVENT_DURATION, durationSeconds)
            put(COL_EVENT_STEPS, steps)
            put(COL_EVENT_DISTANCE, distance)
            put(COL_EVENT_DETAILS, details)
        }
        return db.insert(TABLE_EVENTS, null, values)
    }

    fun logHourlySteps(stepsDelta: Int, distanceDelta: Double): Long {
        if (stepsDelta <= 0 && distanceDelta <= 0.0) return -1
        
        val db = this.writableDatabase
        val dateHour = SimpleDateFormat("yyyy-MM-dd HH", Locale.getDefault()).format(Date())

        // Check if hour already exists
        val cursor = db.query(
            TABLE_HOURLY,
            arrayOf(COL_HOURLY_STEPS, COL_HOURLY_DISTANCE),
            "$COL_HOURLY_DATE_HOUR = ?",
            arrayOf(dateHour),
            null, null, null
        )

        var result: Long = -1
        if (cursor.moveToFirst()) {
            val existingSteps = cursor.getInt(0)
            val existingDistance = cursor.getDouble(1)
            cursor.close()

            val values = ContentValues().apply {
                put(COL_HOURLY_STEPS, existingSteps + stepsDelta)
                put(COL_HOURLY_DISTANCE, existingDistance + distanceDelta)
            }
            result = db.update(TABLE_HOURLY, values, "$COL_HOURLY_DATE_HOUR = ?", arrayOf(dateHour)).toLong()
        } else {
            cursor.close()
            val values = ContentValues().apply {
                put(COL_HOURLY_DATE_HOUR, dateHour)
                put(COL_HOURLY_STEPS, stepsDelta)
                put(COL_HOURLY_DISTANCE, distanceDelta)
            }
            result = db.insert(TABLE_HOURLY, null, values)
        }
        return result
    }

    fun getEventsList(): List<Map<String, Any>> {
        val list = ArrayList<Map<String, Any>>()
        val db = this.readableDatabase
        val cursor = db.query(TABLE_EVENTS, null, null, null, null, null, "$COL_EVENT_TIMESTAMP DESC")
        
        if (cursor.moveToFirst()) {
            do {
                val map = HashMap<String, Any>()
                map["id"] = cursor.getInt(cursor.getColumnIndexOrThrow(COL_EVENT_ID))
                map["type"] = cursor.getString(cursor.getColumnIndexOrThrow(COL_EVENT_TYPE))
                map["timestamp"] = cursor.getLong(cursor.getColumnIndexOrThrow(COL_EVENT_TIMESTAMP))
                map["duration_seconds"] = cursor.getInt(cursor.getColumnIndexOrThrow(COL_EVENT_DURATION))
                map["steps"] = cursor.getInt(cursor.getColumnIndexOrThrow(COL_EVENT_STEPS))
                map["distance"] = cursor.getDouble(cursor.getColumnIndexOrThrow(COL_EVENT_DISTANCE))
                map["details"] = cursor.getString(cursor.getColumnIndexOrThrow(COL_EVENT_DETAILS))
                list.add(map)
            } while (cursor.moveToNext())
        }
        cursor.close()
        return list
    }

    fun getHourlyStepsList(): List<Map<String, Any>> {
        val list = ArrayList<Map<String, Any>>()
        val db = this.readableDatabase
        val cursor = db.query(TABLE_HOURLY, null, null, null, null, null, "$COL_HOURLY_DATE_HOUR DESC")

        if (cursor.moveToFirst()) {
            do {
                val map = HashMap<String, Any>()
                map["id"] = cursor.getInt(cursor.getColumnIndexOrThrow(COL_HOURLY_ID))
                map["date_hour"] = cursor.getString(cursor.getColumnIndexOrThrow(COL_HOURLY_DATE_HOUR))
                map["steps"] = cursor.getInt(cursor.getColumnIndexOrThrow(COL_HOURLY_STEPS))
                map["distance"] = cursor.getDouble(cursor.getColumnIndexOrThrow(COL_HOURLY_DISTANCE))
                list.add(map)
            } while (cursor.moveToNext())
        }
        cursor.close()
        return list
    }

    fun clearAll() {
        val db = this.writableDatabase
        db.execSQL("DELETE FROM $TABLE_EVENTS")
        db.execSQL("DELETE FROM $TABLE_HOURLY")
    }
}
