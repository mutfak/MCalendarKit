//
//  MCalendarView.swift
//  Pods
//
//  Created by Ridvan Kucuk on 5/25/16.
//
//

import UIKit
import EventKit

let cellReuseIdentifier = "CalendarDayCell"

let NUMBER_OF_DAYS_IN_WEEK = 7
let MAXIMUM_NUMBER_OF_ROWS = 6

let HEADER_DEFAULT_HEIGHT : CGFloat = 80.0


let FIRST_DAY_INDEX = 0
let NUMBER_OF_DAYS_INDEX = 1
let DATE_SELECTED_INDEX = 2



extension EKEvent {
    var isOneDay : Bool {
        let components = NSCalendar.currentCalendar().components([.Era, .Year, .Month, .Day], fromDate: self.startDate, toDate: self.endDate, options: NSCalendarOptions())
        return (components.era == 0 && components.year == 0 && components.month == 0 && components.day == 0)
    }
}

@objc public protocol CalendarViewDataSource {
    
    func startDate() -> NSDate?
    func endDate() -> NSDate?
    
}

@objc public protocol CalendarViewDelegate {
    
    optional func calendar(calendar : MCalendarView, canSelectDate date : NSDate) -> Bool
    func calendar(calendar : MCalendarView, didScrollToMonth date : NSDate) -> Void
    func calendar(calendar : MCalendarView, didSelectDate date : NSDate, withEvents events: [EKEvent]) -> Void
    optional func calendar(calendar : MCalendarView, didDeselectDate date : NSDate) -> Void
}

public enum Parameters: String {
    
    case CalendarBackgroundColor = "backgroundColor", SelectedCellBackgroundColor = "selectedCellBackgroundColor", DeselectedCellBackgroundColor = "deselectedCellBackgroundColor", AllowMultipleSelection = "allowMultipleSelection", TodayDeSelectedBackgroundColor = "todayDeselectedBackgroundColor", None = "none"
    
    static let values = [CalendarBackgroundColor, SelectedCellBackgroundColor, DeselectedCellBackgroundColor, AllowMultipleSelection, None]
    
    public static func get(status:String) -> Parameters {
        
        for value in Parameters.values {
            if status == value.rawValue {
                return value
            }
        }
        return Parameters.None
    }
}

public class MCalendarView: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    
    public var dataSource  : CalendarViewDataSource?
    public var delegate    : CalendarViewDelegate?
    
    lazy var gregorian : NSCalendar = {
        
        let cal = NSCalendar(identifier: NSCalendarIdentifierGregorian)!
        
        cal.timeZone = NSTimeZone(abbreviation: "UTC")!
        
        return cal
    }()
    
    public var calendar : NSCalendar {
        return self.gregorian
    }
    
    public var direction : UICollectionViewScrollDirection = .Horizontal {
        didSet {
            if let layout = self.calendarView.collectionViewLayout as? MCalendarFlowLayout {
                layout.scrollDirection = direction

                self.calendarView.reloadData()
            }
        }
    }
    
    private var startDateCache : NSDate = NSDate()
    private var endDateCache : NSDate = NSDate()
    private var startOfMonthCache : NSDate = NSDate()
    private var todayIndexPath : NSIndexPath?
    var displayDate : NSDate?
    
    private(set) var selectedIndexPaths : [NSIndexPath] = [NSIndexPath]()
    private(set) var selectedDates : [NSDate] = [NSDate]()
    
    private var eventsByIndexPath : [NSIndexPath:[EKEvent]] = [NSIndexPath:[EKEvent]]()
    
    public var parameters : [Parameters : AnyObject] = [Parameters : AnyObject]() {
        didSet{
            self.reloadParameters()
        }
    }
    
    private var deselectedCellBackgroundColor : UIColor? // Default cell background Color
    private var selectedCellBackgroundColor : UIColor? // Selected cell background Color
    private var todayDeselectedBackgroundColor : UIColor?
    
    lazy var headerView : MCalendarHeaderView = {
       
        let hv = MCalendarHeaderView(frame:CGRectZero)
        
        return hv
        
    }()
    
    lazy var calendarView : UICollectionView = {
        
        let layout = MCalendarFlowLayout()
        layout.scrollDirection = self.direction
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        
        let cv = UICollectionView(frame: CGRectZero, collectionViewLayout: layout)
        cv.dataSource = self
        cv.delegate = self
        cv.pagingEnabled = true
        
        cv.showsHorizontalScrollIndicator = false
        cv.showsVerticalScrollIndicator = false
        cv.allowsMultipleSelection = true
        
        return cv
        
    }()
    
    override public var frame: CGRect {
        didSet {
            
            let heigh = frame.size.height - HEADER_DEFAULT_HEIGHT
            let width = frame.size.width
            
            self.headerView.frame   = CGRect(x:0.0, y:0.0, width: frame.size.width, height:HEADER_DEFAULT_HEIGHT)
            self.calendarView.frame = CGRect(x:0.0, y:HEADER_DEFAULT_HEIGHT, width: width, height: heigh)
            
            if let layout = self.calendarView.collectionViewLayout as? MCalendarFlowLayout {
                layout.itemSize = CGSizeMake(width / CGFloat(NUMBER_OF_DAYS_IN_WEEK), heigh / CGFloat(MAXIMUM_NUMBER_OF_ROWS))
            }


        }
    }
    
    

    override init(frame: CGRect) {
        super.init(frame : CGRectMake(0.0, 0.0, 200.0, 200.0))
        self.initialSetup()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override public func awakeFromNib() {
        self.initialSetup()
    }
    
    
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
    }
    
    // MARK: Setup
    
    private func initialSetup() {
        
        
        self.clipsToBounds = true
        
        // Register Class
        self.calendarView.registerClass(MCalendarDayCell.self, forCellWithReuseIdentifier: cellReuseIdentifier)

        self.addSubview(self.headerView)
        self.addSubview(self.calendarView)
    }
    
    private func reloadParameters(){
        
        guard let layout = self.calendarView.collectionViewLayout as? MCalendarFlowLayout else {
            return
        }
        if let backgroundColor = self.parameters[.CalendarBackgroundColor] as? UIColor{
            self.calendarView.backgroundColor = backgroundColor
        }
        
        if let multipleSelection = self.parameters[.AllowMultipleSelection] as? Bool{
            self.calendarView.allowsMultipleSelection = multipleSelection
        }
        
        if let cellBGColor = self.parameters[.SelectedCellBackgroundColor] as? UIColor{
            self.selectedCellBackgroundColor = cellBGColor
        }
        
        if let deselectedCellBGColor = self.parameters[.DeselectedCellBackgroundColor] as? UIColor{
            self.deselectedCellBackgroundColor = deselectedCellBGColor
        }
        
        if let todayDeselectedBGColor = self.parameters[.TodayDeSelectedBackgroundColor] as? UIColor{
            
        }
        
        dispatch_async(dispatch_get_main_queue()) {
            self.calendarView.reloadData()
        }
        
    }
    
    
    // MARK: UICollectionViewDataSource
    
    public func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        
        guard let startDate = self.dataSource?.startDate(), endDate = self.dataSource?.endDate() else {
            return 0
        }
       
        startDateCache = startDate
        endDateCache = endDate
        
        // check if the dates are in correct order
        if self.gregorian.compareDate(startDate, toDate: endDate, toUnitGranularity: .Nanosecond) != NSComparisonResult.OrderedAscending {
            return 0
        }
        
        
        let firstDayOfStartMonth = self.gregorian.components( [.Era, .Year, .Month], fromDate: startDateCache)
        firstDayOfStartMonth.day = 1
        
        guard let dateFromDayOneComponents = self.gregorian.dateFromComponents(firstDayOfStartMonth) else {
            return 0
        }
        
        startOfMonthCache = dateFromDayOneComponents
        
        
        let today = NSDate()
        
        if  startOfMonthCache.compare(today) == NSComparisonResult.OrderedAscending &&
            endDateCache.compare(today) == NSComparisonResult.OrderedDescending {
            
            let differenceFromTodayComponents = self.gregorian.components([NSCalendarUnit.Month, NSCalendarUnit.Day], fromDate: startOfMonthCache, toDate: today, options: NSCalendarOptions())
            
            self.todayIndexPath = NSIndexPath(forItem: differenceFromTodayComponents.day, inSection: differenceFromTodayComponents.month)
            
        }
        
        let differenceComponents = self.gregorian.components(NSCalendarUnit.Month, fromDate: startDateCache, toDate: endDateCache, options: NSCalendarOptions())
        
        
        return differenceComponents.month + 1
        
    }
    
    var monthInfo : [Int:[Int]] = [Int:[Int]]()
    
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        let monthOffsetComponents = NSDateComponents()
        
        // offset by the number of months
        monthOffsetComponents.month = section;
        
        guard let correctMonthForSectionDate = self.gregorian.dateByAddingComponents(monthOffsetComponents, toDate: startOfMonthCache, options: NSCalendarOptions()) else {
            return 0
        }
        
        let numberOfDaysInMonth = self.gregorian.rangeOfUnit(.Day, inUnit: .Month, forDate: correctMonthForSectionDate).length
        
        var firstWeekdayOfMonthIndex = self.gregorian.component(NSCalendarUnit.Weekday, fromDate: correctMonthForSectionDate)
        firstWeekdayOfMonthIndex = firstWeekdayOfMonthIndex - 1 // firstWeekdayOfMonthIndex should be 0-Indexed
        firstWeekdayOfMonthIndex = (firstWeekdayOfMonthIndex + 6) % 7 // push it modularly so that we take it back one day so that the first day is Monday instead of Sunday which is the default
        
        monthInfo[section] = [firstWeekdayOfMonthIndex, numberOfDaysInMonth]
        
        return NUMBER_OF_DAYS_IN_WEEK * MAXIMUM_NUMBER_OF_ROWS // 7 x 6 = 42
        
        
    }
    
    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let dayCell = collectionView.dequeueReusableCellWithReuseIdentifier(cellReuseIdentifier, forIndexPath: indexPath) as! MCalendarDayCell
        
        let currentMonthInfo : [Int] = monthInfo[indexPath.section]! // we are guaranteed an array by the fact that we reached this line (so unwrap)
        
        let fdIndex = currentMonthInfo[FIRST_DAY_INDEX]
        let nDays = currentMonthInfo[NUMBER_OF_DAYS_INDEX]
        
        let fromStartOfMonthIndexPath = NSIndexPath(forItem: indexPath.item - fdIndex, inSection: indexPath.section) // if the first is wednesday, add 2
        
        if indexPath.item >= fdIndex &&
            indexPath.item < fdIndex + nDays {
            
            dayCell.textLabel.text = String(fromStartOfMonthIndexPath.item + 1)
            dayCell.hidden = false
            
        }
        else {
            dayCell.textLabel.text = ""
            dayCell.hidden = true
        }
        
        dayCell.selected = selectedIndexPaths.contains(indexPath)
        
        if indexPath.section == 0 && indexPath.item == 0 {
            self.scrollViewDidEndDecelerating(collectionView)
        }
        
        if let idx = todayIndexPath {
            dayCell.isToday = (idx.section == indexPath.section && idx.item + fdIndex == indexPath.item)
        }
    
        if let eventsForDay = eventsByIndexPath[fromStartOfMonthIndexPath] {
            dayCell.eventsCount = eventsForDay.count
            
        } else {
            dayCell.eventsCount = 0
        }
        
//        if let selectedCellBackgroundColor = self.selectedCellBackgroundColor {
//            dayCell.selectedBackgroundColor = selectedCellBackgroundColor
//        }
//        if let deselectedCellBackgroundColor = self.deselectedCellBackgroundColor {
//            dayCell.deselectedBackgroundColor = deselectedCellBackgroundColor
//        }
//        if let todayDeselectedBackgroundColor = self.todayDeselectedBackgroundColor {
//            dayCell.todayDeselectedBackgroundColor = todayDeselectedBackgroundColor
//        }
        
        return dayCell
    }
    
    // MARK: UIScrollViewDelegate
    
    
    public func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        self.calculateDateBasedOnScrollViewPosition(scrollView)
    }
    
    public func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
        self.calculateDateBasedOnScrollViewPosition(scrollView)
    }
    
    
    func calculateDateBasedOnScrollViewPosition(scrollView: UIScrollView) {
        
        let cvbounds = self.calendarView.bounds
        
        var page : Int = Int(floor(self.calendarView.contentOffset.x / cvbounds.size.width))
        
        page = page > 0 ? page : 0
        
        let monthsOffsetComponents = NSDateComponents()
        monthsOffsetComponents.month = page
        
        guard let delegate = self.delegate else {
            return
        }
        
        
        guard let yearDate = self.gregorian.dateByAddingComponents(monthsOffsetComponents, toDate: self.startOfMonthCache, options: NSCalendarOptions()) else {
            return
        }
        
        let month = self.gregorian.component(NSCalendarUnit.Month, fromDate: yearDate) // get month
        
        let monthName = NSDateFormatter().monthSymbols[(month-1) % 12] // 0 indexed array
        
        let year = self.gregorian.component(NSCalendarUnit.Year, fromDate: yearDate)
        
        
        self.headerView.monthLabel.text = monthName + " " + String(year)
        
        self.displayDate = yearDate
        
        
        delegate.calendar(self, didScrollToMonth: yearDate)
        
    }
    
    
    // MARK: UICollectionViewDelegate
    
    private var dateBeingSelectedByUser : NSDate?
    public func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        
        let currentMonthInfo : [Int] = monthInfo[indexPath.section]!
        let firstDayInMonth = currentMonthInfo[FIRST_DAY_INDEX]
        
        let offsetComponents = NSDateComponents()
        offsetComponents.month = indexPath.section
        offsetComponents.day = indexPath.item - firstDayInMonth
        
        
        
        if let dateUserSelected = self.gregorian.dateByAddingComponents(offsetComponents, toDate: startOfMonthCache, options: NSCalendarOptions()) {
            
            dateBeingSelectedByUser = dateUserSelected
            
            // Optional protocol method (the delegate can "object")
            if let canSelectFromDelegate = delegate?.calendar?(self, canSelectDate: dateUserSelected) {
                return canSelectFromDelegate
            }
            
            return true // it can select any date by default
            
        }
        
        return false // if date is out of scope
        
    }
    
    public func selectDate(date : NSDate) {
        
        guard let indexPath = self.indexPathForDate(date) else {
            return
        }
        
        guard self.calendarView.indexPathsForSelectedItems()?.contains(indexPath) == false else {
            return
        }
        
        self.calendarView.selectItemAtIndexPath(indexPath, animated: false, scrollPosition: .None)
        
        selectedIndexPaths.append(indexPath)
        selectedDates.append(date)
        
    }
    
    func deselectDate(date : NSDate) {
        
        guard let indexPath = self.indexPathForDate(date) else {
            return
        }
        
        guard self.calendarView.indexPathsForSelectedItems()?.contains(indexPath) == true else {
            return
        }

        self.calendarView.deselectItemAtIndexPath(indexPath, animated: false)
        
        guard let index = selectedIndexPaths.indexOf(indexPath) else {
            return
        }
        
        
        selectedIndexPaths.removeAtIndex(index)
        selectedDates.removeAtIndex(index)
        
        
    }
    
    func indexPathForDate(date : NSDate) -> NSIndexPath? {
     
        let distanceFromStartComponent = self.gregorian.components( [.Month, .Day], fromDate:startOfMonthCache, toDate: date, options: NSCalendarOptions() )

        guard let currentMonthInfo : [Int] = monthInfo[distanceFromStartComponent.month] else {
            return nil
        }
        
        
        let item = distanceFromStartComponent.day + currentMonthInfo[FIRST_DAY_INDEX]
        let indexPath = NSIndexPath(forItem: item, inSection: distanceFromStartComponent.month)
        
        return indexPath
        
    }
    
    
    public func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        guard let dateBeingSelectedByUser = dateBeingSelectedByUser else {
            return
        }
        
        let currentMonthInfo : [Int] = monthInfo[indexPath.section]!
    
        let fromStartOfMonthIndexPath = NSIndexPath(forItem: indexPath.item - currentMonthInfo[FIRST_DAY_INDEX], inSection: indexPath.section)
        
        var eventsArray : [EKEvent] = [EKEvent]()
        
        if let eventsForDay = eventsByIndexPath[fromStartOfMonthIndexPath] {
            eventsArray = eventsForDay;
        }
        
        delegate?.calendar(self, didSelectDate: dateBeingSelectedByUser, withEvents: eventsArray)
        
        // Update model
        selectedIndexPaths.append(indexPath)
        selectedDates.append(dateBeingSelectedByUser)
    }
    
    public func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
        
        guard let dateBeingSelectedByUser = dateBeingSelectedByUser else {
            return
        }
        
        guard let index = selectedIndexPaths.indexOf(indexPath) else {
            return
        }
        
        delegate?.calendar?(self, didDeselectDate: dateBeingSelectedByUser)
        
        selectedIndexPaths.removeAtIndex(index)
        selectedDates.removeAtIndex(index)
        
    }
    
    
    func reloadData() {
        self.calendarView.reloadData()
    }
    
    
    func setDisplayDate(date : NSDate, animated: Bool) {
        
        if let dispDate = self.displayDate {
            
            // skip is we are trying to set the same date
            if  date.compare(dispDate) == NSComparisonResult.OrderedSame {
                return
            }
            
            
            // check if the date is within range
            if  date.compare(startDateCache) == NSComparisonResult.OrderedAscending ||
                date.compare(endDateCache) == NSComparisonResult.OrderedDescending   {
                return
            }
            
        
            let difference = self.gregorian.components([NSCalendarUnit.Month], fromDate: startOfMonthCache, toDate: date, options: NSCalendarOptions())
            
            let distance : CGFloat = CGFloat(difference.month) * self.calendarView.frame.size.width
            
            self.calendarView.setContentOffset(CGPoint(x: distance, y: 0.0), animated: animated)
            
            
        }
        
    }

}
