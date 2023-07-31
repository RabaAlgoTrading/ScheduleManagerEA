#property copyright "Copyright 2023, Aleix Rabassa"

// Raba enums.
#include <Raba_Includes\Raba_Enums.mqh>
#include <Raba_Includes\Raba_PositionManagement.mqh>
#include <Raba_Includes\Raba_EAManagement.mqh>

/**
 * EXPERT INPUTS
 */
sinput group "### TRADING SCHEDULE PARAMS ###"
input bool InpEnableTradingSchedule = false;                                    // Use trading schedule
input eOutScheduleAction InpOutScheduleAction = CloseAll_;                      // Action when out of schedule
eYears InpTradingYears = _All;                                                  // Years (for optimization)
eMonths InpTradingMonths = All;                                                 // Months (for optimization)
input string InpTradingDays = "1,2,3,4,5";                                      // Trading days (0 sunday - 6 saturday)
input string InpTradingSchedule = "10:00-14:29,15:30-21:00";                    // Schedule "HH:MM-HH:MM,..." (Empty for all day)

/**
 * DATA STRUCTURES
 */
class CScheduleManagement
{
    public:
        bool Init(ulong pExpertMagic, string pExpertSymbol);
        void Exec();
        
        uint TradingDaysInTheWeek();
        bool GetLastInTime();
        string GetScheduleString();
        string GetDaysString();
        CScheduleManagement(void);
      
    private:
        CPositionManagement pm;
        
        ulong ExpertMagic;
        string ExpertSymbol;
        long ScheduleStartTimes[];
        long ScheduleEndTimes[]; 
        long TradingDaysArr[];
        bool LastInTime;
        
        bool InitTradingDaysArr();
        bool InitScheduleArr();  
        bool InTime();      
};

/**
 * CScheduleManagement METHODS
 */
CScheduleManagement::CScheduleManagement() {}

bool CScheduleManagement::Init(ulong pExpertMagic, string pExpertSymbol)
{
    ExpertMagic = pExpertMagic;
    ExpertSymbol = pExpertSymbol;
    LastInTime = true;
    
    if (!InitScheduleArr()) {
        ErrorAlert("Trading schedule param is wrong."); 
        return false;    
    }
    
    if (!InitTradingDaysArr()) {
        ErrorAlert("Trading days param is wrong.");
        return false;    
    }
    
    return true;
}

uint CScheduleManagement::TradingDaysInTheWeek()
{
    return TradingDaysArr.Size();
}

bool CScheduleManagement::InitTradingDaysArr()
{
    string days[];
    StringSplit(InpTradingDays, StringGetCharacter(",", 0), days);
    ArrayResize(TradingDaysArr, days.Size());
    
    // Fill TradingDaysArr.
    for (long i = 0; i < days.Size(); i++) {
        
        // Check format.
        if (StringToInteger(days[i]) < 0 || StringToInteger(days[i]) > 6) {
            return false;
        }
        
        // Set value.
        TradingDaysArr[i] = StringToInteger(days[i]);
    }
    return true;
}

bool CScheduleManagement::InitScheduleArr()
{
    string schedules[];
    string tradingSchedule = InpTradingSchedule;
    
    // No schedule case.
    if (tradingSchedule == "") {
        tradingSchedule = "00:00-23:59";
    }
    
    // Split schedules array.
    StringSplit(tradingSchedule, StringGetCharacter(",", 0), schedules);
    
    // Resize arrays to the number of schedules.
    ArrayResize(ScheduleStartTimes, schedules.Size());
    ArrayResize(ScheduleEndTimes, schedules.Size());
       
    // Fill startTime and endTime arrays.
    for (long i = 0; i < schedules.Size(); i++) {
        
        long startHour = StringToInteger(StringSubstr(schedules[i], 0, 2));
        long startMinute = StringToInteger(StringSubstr(schedules[i], 3, 2));
        long endHour = StringToInteger(StringSubstr(schedules[i], 6, 2));
        long endMinute = StringToInteger(StringSubstr(schedules[i], 9, 2));
        
        // Check format.
        if (startHour > 23 || startHour < 0 || endHour > 23 || endHour < 0
                    || startMinute > 59 || startMinute < 0 || endMinute > 59 || endMinute < 0) {
            return false;            
        }
        
        ScheduleStartTimes[i] = startHour * 60 + startMinute;
        ScheduleEndTimes[i] = endHour * 60 + endMinute;
    }
    return true;
}

bool CScheduleManagement::GetLastInTime()
{
    return LastInTime;
}

string CScheduleManagement::GetScheduleString()
{
    return InpTradingSchedule;
}

string CScheduleManagement::GetDaysString()
{
    return InpTradingDays;
}

bool CScheduleManagement::InTime()
{
    // If schedule is not enabled, return true.
    if (!InpEnableTradingSchedule) return true;
    
    bool inSchedule = false;
    bool inDay = false;
    bool inMonth = false;
    bool inYear = false;
    
    MqlDateTime time;
    TimeCurrent(time);
    int currTime = time.hour * 60 + time.min;
    
    // Check schedules.
    for (long i = 0; i < ScheduleStartTimes.Size(); i++) {
        if ((ScheduleStartTimes[i] < ScheduleEndTimes[i] && currTime >= ScheduleStartTimes[i] && currTime <= ScheduleEndTimes[i])     
                    || (ScheduleStartTimes[i] > ScheduleEndTimes[i] && (currTime >= ScheduleStartTimes[i] || currTime <= ScheduleEndTimes[i]))) {
            inSchedule = true;       
        } 
    }
    if (InpTradingSchedule == "") inSchedule = true;
    
    // Check days.   
    for (long i = 0; i < TradingDaysArr.Size(); i++) {
        if (TradingDaysArr[i] == time.day_of_week) {
            inDay = true;
        }
    }
    
    // Check months.
    if (InpTradingMonths == All || time.mon + 1 == InpTradingMonths) {
        inMonth = true;
    }
    
    // Check years.
    if (InpTradingYears == _All || time.year == InpTradingYears) {
        inYear = true;
    }
    
    return inDay && inMonth && inYear && inSchedule;
}

void CScheduleManagement::Exec()
{
    bool inTime;
    datetime curr = TimeCurrent();
    
    if (InpEnableTradingSchedule) {        
        
        inTime = InTime();
        if (inTime != LastInTime) {
            
            // Case out of time.
            if (!LastInTime) {
                
                // Perform outschedule action.
                if (InpOutScheduleAction == Nothing) {           
                    // PASS.                
                } else if (InpOutScheduleAction == CloseAll_) {  
                    pm.CloseAllPositions(ExpertMagic, ExpertSymbol);
                } else if (InpOutScheduleAction == CloseNegativesBEPositives) {
                    pm.CloseNegativePositions(ExpertMagic, ExpertSymbol);
                    pm.BreakEvenAllPositions(ExpertMagic, ExpertSymbol);
                }       
            }
            
            // Update LastInTime.
            LastInTime = inTime;
        }
    }
}