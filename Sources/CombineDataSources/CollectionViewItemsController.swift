//
//  For credits and licence check the LICENSE file included in this package.
//  (c) CombineOpenSource, Created by Marin Todorov.
//

import UIKit
import Combine

/// A collection view controller acting as data source.
/// `CollectionType` needs to be a collection of collections to represent sections containing rows.
public class CollectionViewItemsController<CollectionType>: NSObject, UICollectionViewDataSource
  where CollectionType: RandomAccessCollection,
  CollectionType.Index == Int,
  CollectionType.Element: Equatable,
  CollectionType.Element: RandomAccessCollection,
  CollectionType.Element.Index == Int,
  CollectionType.Element.Element: Equatable {
  
  public typealias Element = CollectionType.Element.Element
  public typealias CellFactory<Element: Equatable> = (CollectionViewItemsController<CollectionType>, UICollectionView, IndexPath, Element) -> UICollectionViewCell
  public typealias CellConfig<Element, Cell> = (Cell, IndexPath, Element) -> Void
  
  private let cellFactory: CellFactory<Element>
  private var collection: CollectionType!
  
  /// Should the table updates be animated or static.
  public var animated = true
  
  /// The collection view for the data source
  var collectionView: UICollectionView!
  
  /// A fallback data source to implement custom logic like indexes, dragging, etc.
  public var dataSource: UICollectionViewDataSource?
  
  // MARK: - Init
  public init<CellType>(cellIdentifier: String, cellType: CellType.Type, cellConfig: @escaping CellConfig<Element, CellType>) where CellType: UICollectionViewCell {
    cellFactory = { dataSource, collectionView, indexPath, value in
      let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! CellType
      cellConfig(cell, indexPath, value)
      return cell
    }
  }
  
  private init(cellFactory: @escaping CellFactory<Element>) {
    self.cellFactory = cellFactory
  }
  
  deinit {
    debugPrint("Controller is released")
  }
  
  // MARK: - Update collection
  private let fromRow = {(section: Int) in return {(row: Int) in return IndexPath(row: row, section: section)}}
  
  func updateCollection(_ items: CollectionType) {
    // If the changes are not animatable, reload the table
    guard animated, collection != nil, items.count == collection.count else {
      collection = items
      collectionView.reloadData()
      return
    }
    
    // Commit the changes to the collection view sections
    collectionView.performBatchUpdates({[unowned self] in
      for sectionIndex in 0..<items.count {
        let changes = delta(newList: items[sectionIndex], oldList: collection[sectionIndex])
        collectionView.deleteItems(at: changes.removals.map(self.fromRow(sectionIndex)))
        collectionView.insertItems(at: changes.insertions.map(self.fromRow(sectionIndex)))
      }
      collection = items
    }, completion: nil)
  }
  
  private func delta<T>(newList: T, oldList: T) -> (insertions: [Int], removals: [Int])
    where T: RandomAccessCollection, T.Element: Equatable {
      
      let changes = newList.difference(from: oldList)
      
      let insertIndexes = changes.compactMap { change -> Int? in
        guard case CollectionDifference<T.Element>.Change.insert(let offset, _, _) = change else {
          return nil
        }
        return offset
      }
      let deleteIndexes = changes.compactMap { change -> Int? in
        guard case CollectionDifference<T.Element>.Change.remove(let offset, _, _) = change else {
          return nil
        }
        return offset
      }
      
      return (insertions: insertIndexes, removals: deleteIndexes)
  }
  
  // MARK: - UITableViewDataSource protocol
  public func numberOfSections(in collectionView: UICollectionView) -> Int {
    guard collection != nil else { return 0 }
    return collection.count
  }
  
  public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return collection[section].count
  }
  
  public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    cellFactory(self, collectionView, indexPath, collection[indexPath.section][indexPath.row])
  }
  
  // MARK: - Fallback data source object
  override public func forwardingTarget(for aSelector: Selector!) -> Any? {
    return dataSource
  }
}