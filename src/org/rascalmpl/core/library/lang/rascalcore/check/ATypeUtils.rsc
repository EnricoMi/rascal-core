
@license{
  Copyright (c) 2009-2015 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Jurgen J. Vinju - Jurgen.Vinju@cwi.nl - CWI}
@contributor{Mark Hills - Mark.Hills@cwi.nl (CWI)}
@contributor{Anastasia Izmaylova - Anastasia.Izmaylova@cwi.nl (CWI)}
module lang::rascalcore::check::ATypeUtils

import List;
import Set;
import String;
import Node;
import IO;
extend ParseTree;

extend analysis::typepal::TypePal;
extend lang::rascalcore::check::AType;

import lang::rascalcore::check::ATypeInstantiation;

import lang::rascalcore::check::TypePalConfig;
import lang::rascalcore::check::ATypeExceptions;

import lang::rascal::\syntax::Rascal;

str unescape(str s) = replaceAll(s, "\\", "");

AType normalizeType(AType s){
   return
    visit(s){
        case alist(atuple(atypeList(list[AType] tls))) => AType::alrel(atypeList(tls))
        case aset(atuple(atypeList(list[AType] tls)))  => AType::arel(atypeList(tls))
   }
}

@memo
AType expandUserTypes(AType t, Key scope){
    if(overloadedAType(rel[Key, IdRole, AType] overloads) := t){
        filtered = {};
        for(<key, idr, tp> <- overloads){   
            try {
                filtered += <key, idr, expandUserTypes1(tp, scope)>;  
            } catch TypeUnavailable():; // Ignore types that are out of scope
        }
        if(!isEmpty(filtered)) return overloadedAType(filtered);
        throw checkFailed({error("Type <fmt(t)> cannot be expanded in scope, missing imports?", scope)});
    }
    return expandUserTypes1(t, scope);
}

@memo
AType expandUserTypes1(AType t, Key scope){
    //println("expandUserTypes1: <t>");
    return visit(t){
        case u: auser(str uname, ps): {
                //println("expandUserTypes: <u>");  // TODO: handle non-empty qualifier
                expanded = expandUserTypes(getType(uname, scope, dataOrSyntaxIds), scope);
                if(u.label?) expanded.label = u.label;
                //if(u.hasSyntax?) expanded.hasSyntax = u.hasSyntax;
                //println("expanded: <expanded>");
                if(aadt(uname, ps2, SyntaxRole sr) := expanded) {
                   if(size(ps) != size(ps2)) reportError(scope, "Expected <fmt(size(ps2), "type parameter")> for <fmt(expanded)>, found <size(ps)>");
                   expanded.parameters = ps;
                   insert expanded; //aadt(uname, ps);
                } else {
                   params = toList(collectAndUnlabelRascalTypeParams(expanded));  // TODO order issue?
                   nparams = size(params);
                   if(size(ps) != size(params)) reportError(scope, "Expected <fmt(nparams, "type parameter")> for <fmt(expanded)>, found <size(ps)>");
                   if(nparams > 0){
                      try {
                         Bindings b = (params[i].pname : ps[i] | int i <- index(params));
                         expanded = instantiateRascalTypeParams(expanded, b);
                         if(u.label?) expanded.label = u.label;
                         //if(u.hasSyntax?) expanded.hasSyntax = u.hasSyntax;
                         insert expanded;
                       } catch invalidMatch(str reason): 
                                reportError(scope, reason);
                         catch invalidInstantiation(str msg):
                                reportError(scope, msg);
                   } else {
                     insert expanded;
                   }
               }
            }
    }
}

list[str] getUndefinedADTs(AType t, Key scope){
    res = [];
    visit(t){
        case u: auser(str uname, ps): {
                try {
                 println("trying type of <u>");
                 tp = getType(uname, scope, dataOrSyntaxIds);
                 println("tp = <tp>");
                } catch TypeUnavailable(): {
                    res += fmt(u);
                }
      }
      }
      return res;         
}

// ---- print atypes ----------------------------------------------------------

@doc{Pretty printer for Rascal abstract types.}
str prettyPrintAType(aint()) = "int";
str prettyPrintAType(abool()) = "bool";
str prettyPrintAType(areal()) = "real";
str prettyPrintAType(arat()) = "rat";
str prettyPrintAType(astr()) = "str";
str prettyPrintAType(anum()) = "num";
str prettyPrintAType(anode( list[/*str fieldName,*/ AType fieldType] fields)) = "node(<isEmpty(fields) ? "" : intercalate(", ", ["<prettyPrintAType(ft)> <ft.label>" | ft <- fields])>)";
str prettyPrintAType(avoid()) = "void";
str prettyPrintAType(avalue()) = "value";
str prettyPrintAType(aloc()) = "loc";
str prettyPrintAType(adatetime()) = "datetime";
str prettyPrintAType(alist(AType t)) = "list[<prettyPrintAType(t)>]";
str prettyPrintAType(aset(AType t)) = "set[<prettyPrintAType(t)>]";
str prettyPrintAType(atuple(AType ts)) = "tuple[<prettyPrintAType(ts)>]";
str prettyPrintAType(amap(AType d, AType r)) = "map[<prettyPrintAType(d)>, <prettyPrintAType(r)>]";
str prettyPrintAType(arel(AType ts)) = "rel[<prettyPrintAType(ts)>]";
str prettyPrintAType(alrel(AType ts)) = "lrel[<prettyPrintAType(ts)>]";

str prettyPrintAType(afunc(AType ret, atypeList(list[AType] formals), lrel[/*str fieldName,*/ AType fieldType, Expression defaultExp] kwFormals))
                = "<prettyPrintAType(ret)>(<intercalate(",", [prettyPrintAType(f) | f <- formals])><isEmpty(kwFormals) ? "" : ", "><intercalate(",", ["<prettyPrintAType(ft)> <ft.label>=..." | <ft, de> <- kwFormals])>)";

str prettyPrintAType(auser(str s, [])) = "USER TYPE <s>";
str prettyPrintAType(auser(str s, ps)) = "USER TYPE <s>[<prettyPrintAType(ps)>]" when size(ps) > 0;

str prettyPrintAType(aalias(str aname, [], AType aliased)) = "alias <aname> = <prettyPrintAType(aliased)>";
str prettyPrintAType(aalias(str aname, ps, AType aliased)) = "alias <aname>[<prettyPrintAType(ps)>] = <prettyPrintAType(aliased)>" when size(ps) > 0;

str prettyPrintAType(aanno(str aname, AType onType, AType annoType)) = "anno <prettyPrintAType(annoType)> <prettyPrintAType(onType)>@<aname>";

str prettyPrintAType(aadt(str s, [], SyntaxRole _)) = s;
str prettyPrintAType(aadt(str s, ps, SyntaxRole _)) = "<s>[<prettyPrintAType(ps)>]" when size(ps) > 0;

str prettyPrintAType(t: acons(AType adt, /*str consName,*/ 
                list[/*str fieldName,*/ AType fieldType] fields,
                lrel[/*str fieldName,*/ AType fieldType, Expression defaultExp] kwFields))
                 = "<prettyPrintAType(adt)>::<t.label>(<intercalate(", ", ["<prettyPrintAType(ft)> <ft.label>" | ft <- fields])><isEmpty(kwFields) ? "" : ", "><intercalate(",", ["<prettyPrintAType(ft)> <ft.label>=..." | <ft, de> <- kwFields])>)";

str prettyPrintAType(amodule(str mname)) = "module <mname>";         
str prettyPrintAType(aparameter(str pn, AType t)) = t == avalue() ? "&<pn>" : "&<pn> \<: <prettyPrintAType(t)>";
str prettyPrintAType(areified(AType t)) = "type[<prettyPrintAType(t)>]";

// utilities
str prettyPrintAType(overloadedAType(rel[Key, IdRole, AType] overloads))
                = intercalateOr([fmt(prettyPrintAType(t1)) | t1 <- {t | <k, idr, t> <- overloads} ]);

str prettyPrintAType(list[AType] atypes) = intercalate(", ", [prettyPrintAType(t) | t <- atypes]);

str prettyPrintAType(Keyword kw) = "<prettyPrintAType(kw.fieldType) <kw.fieldType.label/*fieldName*/> = <kw.defaultExp>";

// non-terminal symbols
str prettyPrintAType(\prod(AType s, list[AType] fs/*, SyntaxRole _*/)) = "<prettyPrintAType(s)> : (<intercalate(", ", [ prettyPrintAType(f) | f <- fs ])>)"; //TODO others

// terminal symbols
str prettyPrintAType(AType::\lit(str string)) = string;
str prettyPrintAType(AType::\cilit(str string)) = string;
str prettyPrintAType(\char-class(list[ACharRange] ranges)) = "[<intercalate(" ", [ "<r.begin>-<r.end>" | r <- ranges ])>]";

str prettyPrintAType(\start(AType symbol)) = "start[<prettyPrintAType(symbol)>]";

// regular symbols
str prettyPrintAType(AType::\empty()) = "()";
str prettyPrintAType(\opt(AType symbol)) = "<prettyPrintAType(symbol)>?";
str prettyPrintAType(\iter(AType symbol)) = "<prettyPrintAType(symbol)>+";
str prettyPrintAType(\iter-star(AType symbol)) = "<prettyPrintAType(symbol)>*";
str prettyPrintAType(\iter-seps(AType symbol, list[AType] separators)) = "{<prettyPrintAType(symbol)> <intercalate(" ", [ prettyPrintAType(sep) | sep <- separators ])>}+";
str prettyPrintAType(\iter-star-seps(AType symbol, list[AType] separators)) = "{<prettyPrintAType(symbol)> <intercalate(" ", [ prettyPrintAType(sep) | sep <- separators ])>}*";
str prettyPrintAType(\alt(set[AType] alternatives)) = "( <intercalate(" | ", [ prettyPrintAType(a) | a <- alternatives ])> )" when size(alternatives) > 1;
str prettyPrintAType(\seq(list[AType] sequence)) = "( <intercalate(" ", [ prettyPrintAType(a) | a <- sequence ])> )" when size(sequence) > 1;
str prettyPrintAType(\conditional(AType symbol, set[ACondition] conditions)) = "<prettyPrintAType(symbol)> { <intercalate(" ", [ prettyPrintCond(cond) | cond <- conditions ])> }";
default str prettyPrintAType(AType s) = "<s>"; //"<type(s,())>";

private str prettyPrintCond(ACondition::\follow(AType symbol)) = "\>\> <prettyPrintAType(symbol)>";
private str prettyPrintCond(ACondition::\not-follow(AType symbol)) = "!\>\> <prettyPrintAType(symbol)>";
private str prettyPrintCond(ACondition::\precede(AType symbol)) = "<prettyPrintAType(symbol)> \<\<";
private str prettyPrintCond(ACondition::\not-precede(AType symbol)) = "<prettyPrintAType(symbol)> !\<\<";
private str prettyPrintCond(ACondition::\delete(AType symbol)) = "???";
private str prettyPrintCond(ACondition::\at-column(int column)) = "@<column>";
private str prettyPrintCond(ACondition::\begin-of-line()) = "^";
private str prettyPrintCond(ACondition::\end-of-line()) = "$";
private str prettyPrintCond(ACondition::\except(str label)) = "!<label>";

// ---- Predicates, selectors and constructors --------------------------------

// ---- utilities

@doc{Unwraps parameters and conditionals from a type.}
AType unwrapType(p: aparameter(_,tvb)) = p.label? ? unwrapType(tvb)[label=p.label] : unwrapType(tvb);
AType unwrapType(\conditional(AType sym,  set[ACondition] _)) = unwrapType(sym);
default AType unwrapType(AType t) = t;

bool allLabelled(list[AType] tls) = size(tls) == size([tp | tp <- tls, !isEmpty(tp.label)]);

// ---- int

@doc{
.Synopsis
Determine if the given type is an int.
}
bool isIntType(aparameter(_,AType tvb)) = isIntType(tvb);
bool isIntType(aint()) = true;
default bool isIntType(AType _) = false;

@doc{Create a new int type.}
AType makeIntType() = aint();

// ---- bool 
@doc{
.Synopsis
Determine if the given type is a bool.
}
bool isBoolType(aparameter(_,AType tvb)) = isBoolType(tvb);
bool isBoolType(abool()) = true;
default bool isBoolType(AType _) = false;

@doc{Create a new bool type.}
AType makeBoolType() = abool();

// ---- real

@doc{
.Synopsis
Determine if the given type is a real.
}
bool isRealType(aparameter(_,AType tvb)) = isRealType(tvb);
bool isRealType(areal()) = true;
default bool isRealType(AType _) = false;

@doc{Create a new real type.}
AType makeRealType() = areal();

// ---- rat

@doc{
.Synopsis
Determine if the given type is a rational.
}
bool isRatType(aparameter(_,AType tvb)) = isRatType(tvb);
bool isRatType(arat()) = true;
default bool isRatType(AType _) = false;

@doc{Create a new rat type.}
AType makeRatType() = arat();

// ---- str

@doc{
.Synopsis
Determine if the given type is a string.
}
bool isStrType(aparameter(_,AType tvb)) = isStrType(tvb);
bool isStrType(astr()) = true;
default bool isStrType(AType _) = false;

@doc{Create a new str type.}
AType makeStrType() = astr();

// ---- num

@doc{
.Synopsis
Determine if the given type is a num.
}
bool isNumType(aparameter(_,AType tvb)) = isNumType(tvb);
bool isNumType(anum()) = true;
default bool isNumType(AType _) = false;

bool isNumericType(AType t) = isIntType(t) || isRealType(t) || isRatType(t) || isNumType(t);

@doc{Create a new num type.}
AType makeNumType() = anum();

// ---- node

@doc{
.Synopsis
Determine if the given type is a node.
}
bool isNodeType(aparameter(_,AType tvb)) = isNodeType(tvb);
bool isNodeType(anode(_)) = true;
bool isNodeType(aadt(_,_,_)) = true;
default bool isNodeType(AType _) = false;

@doc{Create a new node type.}
AType makeNodeType() = anode([]);

// ---- void

@doc{
.Synopsis
Determine if the given type is a void.
}
bool isVoidType(aparameter(_,AType tvb)) = isVoidType(tvb);
bool isVoidType(avoid()) = true;
default bool isVoidType(AType _) = false;

@doc{Create a new void type.}
AType makeVoidType() = avoid();

// ---- value

@doc{
.Synopsis
Determine if the given type is a value.
}
bool isValueType(aparameter(_,AType tvb)) = isValueType(tvb);
bool isValueType(avalue()) = true;
default bool isValueType(AType _) = false;

@doc{Create a new value type.}
AType makeValueType() = avalue();

// ---- loc

@doc{
.Synopsis
Determine if the given type is a loc.
}
bool isLocType(aparameter(_,AType tvb)) = isLocType(tvb);
bool isLocType(aloc()) = true;
default bool isLocType(AType _) = false;

@doc{Create a new loc type.}
AType makeLocType() = aloc();

// ---- datetime

@doc{
.Synopsis
Determine if the given type is a `datetime`.
}
bool isDateTimeType(aparameter(_,AType tvb)) = isDateTimeType(tvb);
bool isDateTimeType(adatetime()) = true;
default bool isDateTimeType(AType _) = false;

@doc{Create a new datetime type.}
AType makeDateTimeType() = adatetime();

// ---- set

@doc{
.Synopsis
Determine if the given type is a set.
}
bool isSetType(aparameter(_,AType tvb)) = isSetType(tvb);
bool isSetType(aset(_)) = true;
bool isSetType(arel(_)) = true;
default bool isSetType(AType _) = false;

@doc{Create a new set type, given the element type of the set.}
AType makeSetType(AType elementType) {
    return isTupleType(elementType) ? makeRelTypeFromTuple(elementType) : aset(elementType);
}

@doc{Get the element type of a set.}
AType getSetElementType(AType t) {
    if (aset(et) := unwrapType(t)) return et;
    if (arel(ets) := unwrapType(t)) return atuple(ets);
    throw rascalCheckerInternalError("Error: Cannot get set element type from type <fmt(t)>");
}

// ---- rel

@doc{
.Synopsis
Determine if the given type is a relation.
}
bool isRelType(aparameter(_,AType tvb)) = isRelType(tvb);
bool isRelType(arel(_)) = true;
bool isRelType(aset(AType tp)) = true when isTupleType(tp);
default bool isRelType(AType _) = false;

@doc{Ensure that sets of tuples are treated as relations.}
AType aset(AType t) = arel(atypeList(getTupleFields(t))) when isTupleType(t);

@doc{Create a new rel type, given the element types of the fields. Check any given labels for consistency.}
AType makeRelType(AType elementTypes...) {
    set[str] labels = { tp.label | tp <- elementTypes, !isEmpty(tp.label) };
    if (size(labels) == 0 || size(labels) == size(elementTypes))
        return arel(atypeList(elementTypes));
    else
        throw rascalCheckerInternalError("For rel types, either all fields much be given a distinct label or no fields should be labeled."); 
}

@doc{Create a new rel type based on a given tuple type.}
AType makeRelTypeFromTuple(AType t) = arel(atypeList(getTupleFields(t)));

@doc{Get the type of the relation fields as a tuple.}
AType getRelElementType(AType t) {
    if (arel(ets) := unwrapType(t)) return atuple(ets);
    if (aset(tup) := unwrapType(t)) return tup;
    throw rascalCheckerInternalError("Cannot get relation element type from type <fmt(t)>");
}

@doc{Get whether the rel has field names or not.}
bool relHasFieldNames(AType t) {
    if (arel(atypeList(tls)) := unwrapType(t)) return size(tls) == size([tp | tp <- tls, !isEmpty(tp.label)]);
    throw rascalCheckerInternalError("relHasFieldNames given non-Relation type <fmt(t)>");
}

@doc{Get the field names of the rel fields.}
list[str] getRelFieldNames(AType t) {
    if (arel(atypeList(tls)) := unwrapType(t)){
        return [tp.label | tp <- tls];
    }
    throw rascalCheckerInternalError("getRelFieldNames given non-Relation type <fmt(t)>");
}

@doc{Get the fields of a relation.}
list[AType] getRelFields(AType t) {
    if (arel(atypeList(tls)) := unwrapType(t)) return tls;
    if (aset(atuple(atypeList(tls))) := unwrapType(t)) return tls;
    throw rascalCheckerInternalError("getRelFields given non-Relation type <fmt(t)>");
}

// ---- lrel

@doc{
.Synopsis
Determine if the given type is a list relation.
}
bool isListRelType(aparameter(_,AType tvb)) = isListRelType(tvb);
bool isListRelType(alrel(_)) = true;
bool isListRelType(alist(AType tp)) = true when isTupleType(tp);
default bool isListRelType(AType _) = false;

@doc{Ensure that lists of tuples are treated as list relations.}
AType alist(AType t) = alrel(atypeList(getTupleFields(t))) when isTupleType(t);

@doc{Create a new list rel type, given the element types of the fields. Check any given labels for consistency.}
AType makeListRelType(AType elementTypes...) {
    set[str] labels = { tp.label | tp <- elementTypes, !isEmpty(tp.label) };
    if (size(labels) == 0 || size(labels) == size(elementTypes)) 
        return alrel(atypeList(elementTypes));
    else
        throw rascalCheckerInternalError("For lrel types, either all fields much be given a distinct label or no fields should be labeled."); 
}

@doc{Create a new lrel type based on a given tuple type.}
AType makeListRelTypeFromTuple(AType t) = alrel(atypeList(getTupleFields(t)));

@doc{Get the type of the list relation fields as a tuple.}
AType getListRelElementType(AType t) {
    if (alrel(ets) := unwrapType(t)) return atuple(ets);
    if (alist(tup) := unwrapType(t)) return tup;
    throw rascalCheckerInternalError("Cannot get list relation element type from type <fmt(t)>");
}

@doc{Get the field names of the list rel fields.}
list[str] getListRelFieldNames(AType t) {
    if (alrel(atypeList(tls)) := unwrapType(t)){
        return [tp.label | tp <- tls];
    }
    throw rascalCheckerInternalError("getListRelFieldNames given non-List-Relation type <fmt(t)>");
}

@doc{Get the fields of a list relation.}
list[AType] getListRelFields(AType t) {
    if (alrel(atypeList(tls)) := unwrapType(t)) return tls;
    if (alist(atuple(atypeList(tls))) := unwrapType(t)) return tls;
    throw rascalCheckerInternalError("getListRelFields given non-List-Relation type <fmt(t)>");
}

// ---- tuple

@doc{
.Synopsis
Determine if the given type is a tuple.
}
bool isTupleType(aparameter(_,AType tvb)) = isTupleType(tvb);
bool isTupleType(atuple(_)) = true;
default bool isTupleType(AType _) = false;

@doc{Create a new tuple type, given the element types of the fields. Check any given labels for consistency.}
AType makeTupleType(AType elementTypes...) {
    set[str] labels = { tp.label | tp <- elementTypes, !isEmpty(tp.label) };
    if(size(labels) > 0 && size(labels) != size(elementTypes))
        elementTypes = [unset(e, "label") | e <- elementTypes];
    return atuple(atypeList(elementTypes));
    //else
    //    throw rascalCheckerInternalError("For tuple types, either all fields much be given a distinct label or no fields should be labeled."); 
}

@doc{Indicate if the given tuple has a field of the given name.}
bool tupleHasField(AType t, str fn) {
    return atuple(atypeList(tas)) := unwrapType(t) && fn in { tp.label | tp <- tas, tp.label? } ;
}

@doc{Indicate if the given tuple has a field with the given field offset.}
bool tupleHasField(AType t, int fn) {
    return atuple(atypeList(tas)) := unwrapType(t) && 0 <= fn && fn < size(tas);
}

@doc{Get the type of the tuple field with the given name.}
AType getTupleFieldType(AType t, str fn) {
    if (atuple(atypeList(tas)) := unwrapType(t)) {
        for(tp <- tas){
            if(tp.label == fn) return tp;
        }
        throw rascalCheckerInternalError("Tuple <fmt(t)> does not have field <fn>");
    }
    throw rascalCheckerInternalError("getTupleFieldType given unexpected type <fmt(t)>");
}

@doc{Get the type of the tuple field at the given offset.}
AType getTupleFieldType(AType t, int fn) {
    if (atuple(atypeList(tas)) := t) {
        if (0 <= fn && fn < size(tas)) return unwrapType(tas[fn]);
        throw rascalCheckerInternalError("Tuple <fmt(t)> does not have field <fn>");
    }
    throw rascalCheckerInternalError("getTupleFieldType given unexpected type <fmt(t)>");
}

@doc{Get the types of the tuple fields, with labels removed}
list[AType] getTupleFieldTypes(AType t) {
    if (atuple(atypeList(tas)) := t)
        return tas;
    throw rascalCheckerInternalError("Cannot get tuple field types from type <fmt(t)>"); 
}

@doc{Get the fields of a tuple as a list.}
list[AType] getTupleFields(AType t) {
    if (atuple(atypeList(tas)) := unwrapType(t)) return tas;
    throw rascalCheckerInternalError("Cannot get tuple fields from type <fmt(t)>"); 
}

@doc{Get the number of fields in a tuple.}
int getTupleFieldCount(AType t) = size(getTupleFields(t));

@doc{Does this tuple have field names?}
bool tupleHasFieldNames(AType t) {
    if (tup: atuple(atypeList(tas)) := unwrapType(t)) return size(tas) == size([tp | tp <- tas, !isEmpty(tp.label)]);
    throw rascalCheckerInternalError("tupleHasFieldNames given non-Tuple type <fmt(t)>");
}

@doc{Get the names of the tuple fields.}
list[str] getTupleFieldNames(AType t) {
    if (atuple(atypeList(tls)) := unwrapType(t)) {
        if (allLabelled(tls)) {
            return [tp.label | tp <- tls];
        }
        throw rascalCheckerInternalError("getTupleFieldNames given tuple type without field names: <fmt(t)>");        
    }
    throw rascalCheckerInternalError("getTupleFieldNames given non-Tuple type <fmt(t)>");
}

@doc{Get the name of the tuple field at the given offset.}
str getTupleFieldName(AType t, int idx) {
    list[str] names = getTupleFieldNames(t);
    if (0 <= idx && idx < size(names)) return names[idx];
    throw rascalCheckerInternalError("getTupleFieldName given invalid index <idx>");
}

// ---- list

@doc{
.Synopsis
Determine if the given type is a list.
}
bool isListType(aparameter(_,AType tvb)) = isListType(tvb);
bool isListType(alist(_)) = true;
bool isListType(alrel(_)) = true;
default bool isListType(AType _) = false;

@doc{Create a new list type, given the element type of the list.}
AType makeListType(AType elementType) {
    return isTupleType(elementType) ? makeListRelTypeFromTuple(elementType) : alist(elementType);
} 

@doc{Get the element type of a list.}
AType getListElementType(AType t) {
    if (alist(et) := unwrapType(t)) return et;
    if (alrel(ets) := unwrapType(t)) return atuple(ets);    
    throw rascalCheckerInternalError("Cannot get list element type from type <fmt(t)>");
}  

// ---- map

@doc{
.Synopsis
Determine if the given type is a map.
}
bool isMapType(x:aparameter(_,AType tvb)) = isMapType(tvb);
bool isMapType(x:amap(_,_)) = true;
default bool isMapType(AType x) = false;

@doc{Create a new map type, given the types of the domain and range. Check to make sure field names are used consistently.}
AType makeMapType(AType domain, AType range) {
    if(!isEmpty(domain.label) && !isEmpty(range.label)){
        if(domain.label != range.label) return amap(domain, range);
        throw rascalCheckerInternalError("The field names of the map domain and range must be distinct; found <fmt(domain.label)>");
    }
    else if(!isEmpty(domain.label)) return amap(unset(domain,"label"),range);
    else if(!isEmpty(range.label)) return amap(domain,unset(range, "label"));
    return amap(domain, range);
}

@doc{Get the domain and range of the map as a tuple.}
AType getMapFieldsAsTuple(AType t) {
    if (amap(dt,rt) := unwrapType(t)) return atuple(atypeList([dt,rt]));
    throw rascalCheckerInternalError("getMapFieldsAsTuple called with unexpected type <fmt(t)>");
}       

@doc{Check to see if a map defines a field (by name).}
bool mapHasField(AType t, str fn) = tupleHasField(getMapFieldsAsTuple(t),fn);

@doc{Check to see if a map defines a field (by index).}
bool mapHasField(AType t, int fn) = tupleHasField(getMapFieldsAsTuple(t),fn);

@doc{Return the type of a field defined on a map (by name).}
AType getMapFieldType(AType t, str fn) = getTupleFieldType(getMapFieldsAsTuple(t),fn);

@doc{Return the type of a field defined on a map (by index).}
AType getMapFieldType(AType t, int fn) = getTupleFieldType(getMapFieldsAsTuple(t),fn);

@doc{Get the fields in a map as a list of fields.}
list[AType] getMapFields(AType t) = getTupleFields(getMapFieldsAsTuple(t));

@doc{Check to see if the map has field names.}
bool mapHasFieldNames(AType t) = tupleHasFieldNames(getMapFieldsAsTuple(t));

@doc{Get the field names from the map fields.}
list[str] getMapFieldNames(AType t) {
    if ([dm, rng] := getMapFields(t)) {
        return [ dm.label, rng.label ];
    }
    throw rascalCheckerInternalError("getMapFieldNames given map type without field names: <fmt(t)>");        
}

@doc{Get the field name for the field at a specific index.}
str getMapFieldName(AType t, int idx) = getMapFieldNames(t)[idx];

@doc{Get the domain type of the map.}    
AType getMapDomainType(AType t) = unwrapType(getMapFields(t)[0]);

@doc{Get the range type of the map.}
AType getMapRangeType(AType t) = unwrapType(getMapFields(t)[1]);

// ---- bag

@doc{
.Synopsis
Determine if the given type is a bag (bags are not yet implemented).
}
bool isBagType(aparameter(_,AType tvb)) = isBagType(tvb);
bool isBagType(abag(_)) = true;
default bool isBagType(AType _) = false;

@doc{Create a new bag type, given the element type of the bag.}
AType makeBagType(AType elementType) = abag(elementType);


@doc{Get the element type of a bag.}
AType getBagElementType(AType t) {
    if (abag(et) := unwrapType(t)) return et;
    throw rascalCheckerInternalError("Cannot get set element type from type <fmt(t)>");
}

@doc{
.Synopsis
Determine if the given type is an Abstract Data Type (ADT).
}
bool isADTType(aparameter(_,AType tvb)) = isADTType(tvb);
bool isADTType(aadt(_,_,_)) = true;
bool isADTType(areified(_)) = true;
default bool isADTType(AType _) = false;

@doc{Create a new parameterized ADT type with the given type parameters}
AType makeParameterizedADTType(str n, AType p...) = aadt(n,p, dataSyntax());

@doc{Create a new ADT type with the given name.}
AType makeADTType(str n) = aadt(n,[], dataSyntax());

@doc{Get the name of the ADT.}
str getADTName(AType t) {
    if (aadt(n,_,_) := unwrapType(t)) return n;
    if (acons(a,/*_,*/_,_) := unwrapType(t)) return getADTName(a);
    if (areified(_) := unwrapType(t)) return "type";
    throw rascalCheckerInternalError("getADTName, invalid type given: <fmt(t)>");
}

@doc{Get the type parameters of an ADT.}
list[AType] getADTTypeParameters(AType t) {
    if (aadt(n,ps,_) := unwrapType(t)) return ps;
    if (acons(a,/*_,*/_,_) := unwrapType(t)) return getADTTypeParameters(a);
    if (areified(_) := unwrapType(t)) return [];
    throw rascalCheckerInternalError("getADTTypeParameters given non-ADT type <fmt(t)>");
}

@doc{Return whether the ADT has type parameters.}
bool adtHasTypeParameters(AType t) = size(getADTTypeParameters(t)) > 0;


@doc{
.Synopsis
Determine if the given type is a constructor.
}
bool isConstructorType(aparameter(_,AType tvb)) = isConstructorType(tvb);
bool isConstructorType(acons(AType _, /*str _,*/ _, _)) = true;
default bool isConstructorType(AType _) = false;

@doc{Get the ADT type of the constructor.}
AType getConstructorResultType(AType ct) {
    if (acons(a,/*_,*/_,_) := unwrapType(ct)) return a;
    throw rascalCheckerInternalError("Cannot get constructor ADT type from non-constructor type <fmt(ct)>");
}

@doc{Get a list of the argument types in a constructor.}
list[AType] getConstructorArgumentTypes(AType ct) {
    if (acons(_,/*_,*/list[AType/*NamedField*/] cts,_) := unwrapType(ct)) return cts/*<1>*/;
    throw rascalCheckerInternalError("Cannot get constructor arguments from non-constructor type <fmt(ct)>");
}

@doc{Get a tuple with the argument types as the fields.}
AType getConstructorArgumentTypesAsTuple(AType ct) {
    return atuple(atypeList(getConstructorArgumentTypes(ct)));
}

@doc{
.Synopsis
Determine if the given type is a function.
}
bool isFunctionType(aparameter(_,AType tvb)) = isFunctionType(tvb);
bool isFunctionType(afunc(_,_,_)) = true;
default bool isFunctionType(AType _) = false;

@doc{Get a list of arguments for the function.}
list[AType] getFunctionArgumentTypes(AType ft) {
    if (afunc(_, atypeList(ats), _) := unwrapType(ft)) return ats;
    throw rascalCheckerInternalError("Cannot get function arguments from non-function type <fmt(ft)>");
}

@doc{Get the arguments for a function in the form of a tuple.}
AType getFunctionArgumentTypesAsTuple(AType ft) {
    if (afunc(_, ats, _) := unwrapType(ft)) return atuple(ats);
    throw rascalCheckerInternalError("Cannot get function arguments from non-function type <fmt(ft)>");
}

@doc{Get the return type for a function.}
AType getFunctionReturnType(AType ft) {
    if (afunc(rt, _, _) := unwrapType(ft)) return rt;
    throw rascalCheckerInternalError("Cannot get function return type from non-function type <fmt(ft)>");
}

@doc{
.Synopsis
Determine if the given type is a reified type.
}
bool isReifiedType(aparameter(_,AType tvb)) = isReifiedType(tvb);
bool isReifiedType(areified(_)) = true;
default bool isReifiedType(AType _) = false;

@doc{Create a type representing the reified form of the given type.}
AType makeReifiedType(AType mainType) = areified(mainType);

@doc{Get the type that has been reified and stored in the reified type.}
AType getReifiedType(AType t) {
    if (areified(rt) := unwrapType(t)) return rt;
    throw rascalCheckerInternalError("getReifiedType given unexpected type: <fmt(t)>");
}

@doc{
.Synopsis
Determine if the given type is an type variable (parameter).
}
bool isRascalTypeParam(aparameter(_,_)) = true;
default bool isRascalTypeParam(AType _) = false;

@doc{Create a type representing a type parameter (type variable).}
AType makeTypeVar(str varName) = aparameter(varName, avalue());

@doc{Create a type representing a type parameter (type variable) and bound.}
AType makeTypeVarWithBound(str varName, AType varBound) = aparameter(varName, varBound);

@doc{Get the name of a Rascal type parameter.}
str getRascalTypeParamName(AType t) {
    if (aparameter(tvn,_) := t) return tvn;
    throw rascalCheckerInternalError("getRascalTypeParamName given unexpected type: <fmt(t)>");
}

@doc{Get the bound of a type parameter.}
AType getRascalTypeParamBound(AType t) {
    if (aparameter(_,tvb) := t) return tvb;
    throw rascalCheckerInternalError("getRascalTypeParamBound given unexpected type: <fmt(t)>");
}

@doc{Get all the type parameters inside a given type.}
set[AType] collectRascalTypeParams(AType t) {
    
    return { rt | / AType rt : aparameter(_,_) := t };
    //return { unset(rt, "label") | / AType rt : aparameter(_,_) := t }; // TODO: "label" is unset to enable subset check later, reconsider
}

@doc{Get all the type parameters inside a given type.}
set[AType] collectAndUnlabelRascalTypeParams(AType t) {
   return { unset(rt, "label") | / AType rt : aparameter(_,_) := t }; // TODO: "label" is unset to enable subset check later, reconsider
}

@doc{Provide an initial type map from the type parameters in the type to void.}
map[str,AType] initializeRascalTypeParamMap(AType t) {
    set[AType] rt = collectRascalTypeParams(t);
    return ( getRascalTypeParamName(tv) : makeVoidType() | tv <- rt );
}

@doc{See if a type contains any type parameters.}
bool typeContainsRascalTypeParams(AType t) = size(collectRascalTypeParams(t)) > 0;

@doc{Return the names of all type variables in the given type.}
set[str] typeParamNames(AType t) {
    return { tvn | aparameter(tvn,_) <- collectRascalTypeParams(t) };
}

// ---- element & container types

@doc{Is this type a non-container type?}
bool isElementType(AType t) = 
    isIntType(t) || isBoolType(t) || isRealType(t) || isRatType(t) || isStrType(t) || 
    isNumType(t) || isNodeType(t) || isVoidType(t) || isValueType(t) || isLocType(t) || 
    isDateTimeType(t) || isTupleType(t) || isADTType(t) || isConstructorType(t) ||
    isFunctionType(t) || isReifiedType(t) || isNonTerminalType(t);

@doc{Is this type a container type?}
bool isContainerType(AType t) =
    isSetType(t) || isListType(t) || isMapType(t) || isBagType(t);
    
bool isEnumeratorType(AType t) =
    isSetType(t) || isListType(t) || isMapType(t) || isADTType(t) || isTupleType(t) || isNodeType(t) ||
    isNonTerminalIterType(t) || isNonTerminalOptType(t);

// ---- literal
@doc{Synopsis: Determine if the given type is a literal.}
bool isLiteralType(aparameter(_,AType tvb)) = isLiteralType(tvb);
bool isLiteralType(lit(_)) = true;
bool isLiteralType(cilit(_)) = true;
default bool isLiteralType(AType _) = false;

// ---- layout
@doc{Synopsis: Determine if the given type is a layout type.}
bool isLayoutType(aparameter(_,AType tvb)) = isLayoutType(tvb);

bool isLayoutType(AType::\conditional(AType ss,_)) = isLayoutType(ss);
bool isLayoutType(t:aadt(adtName,_,SyntaxRole sr)) = sr == layoutSyntax();
bool isLayoutType(AType::\start(AType ss)) = isLayoutType(ss);
bool isLayoutType(AType::\iter(AType s)) = isLayoutType(s);
bool isLayoutType(AType::\iter-star(AType s)) = isLayoutType(s);
bool isLayoutType(AType::\iter-seps(AType s,_)) = isLayoutType(s);
bool isLayoutType(AType::\iter-star-seps(AType s,_)) = isLayoutType(s);

bool isLayoutType(AType::\opt(AType s)) = isLayoutType(s);
bool isLayoutType(AType::\alt(set[AType] alts)) = any(a <- alts, isLayoutType(a));
bool isLayoutType(AType::\seq(list[AType] symbols)) = all(s <- symbols, isLayoutType(s));
default bool isLayoutType(AType _) = false;

// ---- nonterminal

@doc{Synopsis: Determine if the given type is a nonterminal.}
bool isNonTerminalType(aparameter(_,AType tvb)) = isNonTerminalType(tvb);
bool isNonTerminalType(AType::\conditional(AType ss,_)) = isNonTerminalType(ss);
bool isNonTerminalType(t:aadt(adtName,_,SyntaxRole sr)) = isConcreteSyntaxRole(sr) || adtName == "Tree";
bool isNonTerminalType(AType::\start(AType ss)) = isNonTerminalType(ss);
bool isNonTerminalType(AType::\iter(_)) = true;
bool isNonTerminalType(AType::\iter-star(_)) = true;
bool isNonTerminalType(AType::\iter-seps(_,_)) = true;
bool isNonTerminalType(AType::\iter-star-seps(_,_)) = true;
bool isNonTerminalType(AType::\empty()) = true;
bool isNonTerminalType(AType::\opt(_)) = true;
bool isNonTerminalType(AType::\alt(_)) = true;
bool isNonTerminalType(AType::\seq(_)) = true;

default bool isNonTerminalType(AType _) = false;    

bool isNonTerminalIterType(aparameter(_,AType tvb)) = isNonTerminalIterType(tvb);
bool isNonTerminalIterType(AType::\iter(_)) = true;
bool isNonTerminalIterType(AType::\iter-star(_)) = true;
bool isNonTerminalIterType(AType::\iter-seps(_,_)) = true;
bool isNonTerminalIterType(AType::\iter-star-seps(_,_)) = true;
default bool isNonTerminalIterType(AType _) = false;    

AType getNonTerminalIterElement(aparameter(_,AType tvb)) = getNonTerminalIterElement(tvb);
AType getNonTerminalIterElement(AType::\iter(AType i)) = i;
AType getNonTerminalIterElement(AType::\iter-star(AType i)) = i;
AType getNonTerminalIterElement(AType::\iter-seps(AType i,_)) = i;
AType getNonTerminalIterElement(AType::\iter-star-seps(AType i,_)) = i;
default AType getNonTerminalIterElement(AType i) {
    throw rascalCheckerInternalError("<fmt(i)> is not an iterable non-terminal type");
}   

bool isNonTerminalOptType(aparameter(_,AType tvb)) = isNonTerminalOptType(tvb);
bool isNonTerminalOptType(AType::\opt(AType ot)) = true;
default bool isNonTerminalOptType(AType _) = false;

AType getNonTerminalOptType(aparameter(_,AType tvb)) = getNonTerminalOptType(tvb);
AType getNonTerminalOptType(AType::\opt(AType ot)) = ot;
default AType getNonTerminalOptType(AType ot) {
    throw rascalCheckerInternalError("<fmt(ot)> is not an optional non-terminal type");
}

// TODO
bool isStartNonTerminalType(aparameter(_,AType tvb)) = isNonTerminalType(tvb);
bool isStartNonTerminalType(AType::\start(_)) = true;
default bool isStartNonTerminalType(AType _) = false;    

AType getStartNonTerminalType(aparameter(_,AType tvb)) = getStartNonTerminalType(tvb);
AType getStartNonTerminalType(AType::\start(AType s)) = s;
default AType getStartNonTerminalType(AType s) {
    throw rascalCheckerInternalError("<fmt(s)> is not a start non-terminal type");
}

AType removeConditional(cnd:conditional(AType s, set[ACondition] _)) = cnd.label? ? s[label=cnd.label] : s;
default AType removeConditional(AType s) = s;

// ---- fields
AType getField(Tree current, acons(AType adt, /*str consName,*/ list[AType/*NamedField*/] fields, list[Keyword] kwFields), str fieldName, Key scope){

}

AType getField(Tree current, AType t, str fieldName, Key scope){

}
default AType getField(Tree current, AType t, str fieldName, Key scope){
    throw throw checkFailed({error("Field <fmt(fieldName)> does not exist on type <fmt(t)>", getLoc(current))});
}