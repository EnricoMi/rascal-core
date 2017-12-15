module lang::rascalcore::check::Operators

extend analysis::typepal::TypePal;

import lang::rascalcore::check::AType;
import lang::rascalcore::check::ATypeUtils;
import lang::rascalcore::check::Scope;
import lang::rascalcore::check::ATypeInstantiation;

import lang::rascal::\syntax::Rascal;

AType unaryOp(str op, AType(Tree, AType) computeType, Tree current, AType t1){
//println("unaryOp: <op>");
    t1 = instantiate(t1);
    if(!isFullyInstantiated(t1)){
       throw TypeUnavailable();
    }
    if(overloadedAType(rel[Key, IdRole, AType] overloads) := t1){
        bin_overloads = {};
        for(<key, idr, tp> <- overloads){
            try {
                bin_overloads += <key, idr, unaryOp(op, computeType, current, tp)>;
             } catch checkFailed(set[Message] msgs): {
                ; // do nothing and try next overload
             } catch e: {
                ; // do nothing and try next overload
             }
        }
        if(isEmpty(bin_overloads)) reportError(current, "<fmt(op)> cannot be applied to <fmt(t1)>");
        return overloadedAType(bin_overloads);
    }
    
    return computeType(current, t1);
}

AType binaryOp(str op, AType(Tree, AType, AType) computeType, Tree current, AType t1, AType t2){
//println("binaryOp: <op>, <current>, <t1>, <t2>");
    t1 = instantiate(t1);
    t2 = instantiate(t2);
    if(!(isFullyInstantiated(t1) && isFullyInstantiated(t2))){
       throw TypeUnavailable();
    }
    if(overloadedAType(rel[Key, IdRole, AType] overloads) := t1){
        bin_overloads = {};
        for(<key, idr, tp> <- overloads){
            try {
                bin_overloads += <key, idr, binaryOp(op, computeType, current, tp, t2)>;
             } catch checkFailed(set[Message] msgs): {
                ; // do nothing and try next overload
             } catch e: {
                ; // do nothing and try next overload
             }
        }
        if(isEmpty(bin_overloads)) reportError(current, "<fmt(op)> cannot be applied to <fmt(t1)> and <fmt(t2)>");
        return overloadedAType(bin_overloads);
    }
    
    if(overloadedAType(rel[Key, IdRole, AType] overloads) := t2){
        bin_overloads = {};
        for(<key, idr, tp> <- overloads){
            try {
                bin_overloads += < key, idr, binaryOp(op, computeType, current, t1, tp)>;
             } catch checkFailed(set[Message] msgs): {
                ; // do nothing and try next overload
             } catch e: {
                ; // do nothing and try next overload
             }
        }
        if(isEmpty(bin_overloads)) reportError(current, "<fmt(op)> cannot be applied to <fmt(t1)> and <fmt(t2)>");
        return overloadedAType(bin_overloads);
    }
    return computeType(current, t1, t2);
}

@doc{Calculate the arith type for the numeric types, taking account of coercions.}
public AType numericArithTypes(AType l, AType r) {
    if (isIntType(l) && isIntType(r)) return aint();
    if (isIntType(l) && isRatType(r)) return arat();
    if (isIntType(l) && isRealType(r)) return areal();
    if (isIntType(l) && isNumType(r)) return anum();

    if (isRatType(l) && isIntType(r)) return arat();
    if (isRatType(l) && isRatType(r)) return arat();
    if (isRatType(l) && isRealType(r)) return areal();
    if (isRatType(l) && isNumType(r)) return anum();

    if (isRealType(l) && isIntType(r)) return areal();
    if (isRealType(l) && isRatType(r)) return areal();
    if (isRealType(l) && isRealType(r)) return areal();
    if (isRealType(l) && isNumType(r)) return anum();

    if (isNumType(l) && isIntType(r)) return anum();
    if (isNumType(l) && isRatType(r)) return anum();
    if (isNumType(l) && isRealType(r)) return anum();
    if (isNumType(l) && isNumType(r)) return anum();

    throw "Only callable for numeric types, given <prettyPrintType(l)> and <prettyPrintType(r)>";
}

// ---- is

void collect(current: (Expression) `<Expression e> is <Name n>`, TBuilder tb){
    tb.calculate("is", current, [e], AType () { return unaryOp("is", computeIsType, current, getType(e));  });
    collect(e, tb); 
}

AType computeIsType(Tree current, AType t1){
    if(isNodeType(t1) || isADTType(t1) || isNonTerminalType(t1)) return abool();
    reportError(current, "Invalid type: expected node, ADT, or concrete syntax types, found <fmt(t1)>");
}

// ---- has

void collect(current: (Expression) `<Expression e> has <Name n>`, TBuilder tb){
    tb.calculate("has", current, [e], AType () { return unaryOp("has", computeHasType, current, getType(e)); });
    collect(e, tb); 
} 

AType computeHasType(Tree current, AType t1){
    if (isRelType(t1) || isListRelType(t1) || isTupleType(t1) || isADTType(t1) || isNonTerminalType(t1) || isNodeType(t1)) return abool();
             reportError(current, "Invalid type: expected relation, tuple, node or ADT types, found <fmt(t1)>");

}

// ---- transitive closure
 
void collect(current: (Expression) `<Expression arg> +`, TBuilder tb){
    tb.calculate("transitive closure", current, [arg],
        AType() { return unaryOp("transitive closure", computeTransClosureType, current, getType(arg)); });
    
    collect(arg, tb); 
} 

AType computeTransClosureType(Tree current, AType t1){

    // Special case: if we have list[void] or set[void], these become lrel[void,void] and rel[void,void]
    if (isListType(t1) && isVoidType(getListElementType(t1)))
        return makeListRelType([makeVoidType(),makeVoidType()]);
    if (isSetType(t1) && isVoidType(getSetElementType(t1)))
        return makeRelType([makeVoidType(),makeVoidType()]);
        
    // Normal case: we have an actual list or relation
    if (isRelType(t1) || isListRelType(t1)) {
        list[AType] flds = isRelType(t1) ? getRelFields(t1) : getListRelFields(t1);
        if (size(flds) == 0) {
            return t1;
        } else if (size(flds) == 2 && equivalent(flds[0],flds[1])) {    
            return t1;
        } else {
            reportError(current, "Invalid type: expected a binary relation over equivalent types, found <fmt(t1)>");
        }
    } else {
        reportError(current, "Invalid type: expected a binary relation, found <fmt(t1)>");
    }
}
// ---- reflexive transitive closure

void collect(current: (Expression) `<Expression arg> *`, TBuilder tb){
    tb.calculate("reflexive transitive closure", current, [arg],
        AType() { return unaryOp("reflexive transitive closure", computeTransClosureType, current, getType(arg)); });
    
    collect(arg, tb); 
} 

// ---- isDefined

void collect(current: (Expression) `<Expression arg> ?`, TBuilder tb){
    tb.fact(current, abool());
    collect(arg, tb); 
}

// ---- negation

void collect(current: (Expression) `! <Expression arg>`, TBuilder tb){
    tb.calculate("negation", current, [arg],
       AType (){ return unaryOp("negation", computeNegation, current, getType(arg)); });
    collect(arg, tb); 
}

AType computeNegation(Tree current, AType t1){
    if(isBoolType(t1)) return abool();
    reportError(current, "Negation not defined on <fmt(t1)>");
}

// ---- negative

void collect(current: (Expression) `- <Expression arg>`, TBuilder tb){
    tb.calculate("negative", current, [arg],
       AType(){ return unaryOp("negative", computeNegative, current, getType(arg)); });
    collect(arg, tb); 
}

AType computeNegative(Tree current, AType t1){
    if(isNumericType(t1)) return t1;
    reportError(current, "Negative not defined on <fmt(t1)>");
}
// ---- splice

void collect(current: (Expression) `* <Expression arg>`, TBuilder tb){
    tb.calculate("splice", current, [arg], 
       AType(){ return unaryOp("splice", computeSpliceType, current, getType(arg)); });
    collect(arg, tb); 
}

AType computeSpliceType(Tree current, AType t1){    
    if (isListType(t1)) return getListElementType(t1);
    if (isSetType(t1)) return getSetElementType(t1);
    if (isBagType(t1)) return getBagElementType(t1);
    if (isRelType(t1)) return getRelElementType(t1);
    if (isListRelType(t1)) return getListRelElementType(t1);
    return t1;
}

// ---- asType

void collect(current: (Expression)`[ <Type t> ] <Expression e>`, TBuilder tb){
    scope = tb.getScope();
    reqType = convertType(t, tb);
    
    tb.calculate("asType", current, [e],
        AType() { expType = getType(e);
                  subtype(expType, astr()) || subtype(expType, aloc()) || reportError(e, "Expected str, instead found <fmt(getType(e))>");
                  return expandUserTypes(reqType, scope);
                });
    collect(e, tb);
}

// ---- composition

void collect(current: (Expression) `<Expression lhs> o <Expression rhs>`, TBuilder tb){
    tb.calculate("composition", current, [lhs, rhs],  
       AType(){ return binaryOp("composition", computeCompositionType, current, getType(lhs), getType(rhs)); 
            //return computeCompositionType(current, getType(lhs), getType(rhs));
       });
    collect(lhs, rhs, tb); 
}

AType computeCompositionType(Tree current, AType t1, AType t2){  

    // Special handling for list[void] and set[void], these should be treated as lrel[void,void]
    // and rel[void,void], respectively
    if (isListType(t1) && isVoidType(getListElementType(t1))) t1 = makeListRelType(makeVoidType(),makeVoidType());
    if (isListType(t2) && isVoidType(getListElementType(t2))) t2 = makeListRelType(makeVoidType(),makeVoidType());
    if (isSetType(t1) && isVoidType(getSetElementType(t1))) t1 = makeRelType(makeVoidType(),makeVoidType());
    if (isSetType(t2) && isVoidType(getSetElementType(t2))) t2 = makeRelType(makeVoidType(),makeVoidType());
    
    
    if (isMapType(t1) && isMapType(t2)) {
        if (subtype(getMapRangeType(t1),getMapDomainType(t2))) {
            return makeMapType(getMapDomainType(t1),getMapRangeType(t2));
        } else {
            reportError(current, "<fmt(getMapRangeType(t1))> must be a subtype of <fmt(getMapDomainType(t2))>");
        }
    }
    
    if (isRelType(t1) && isRelType(t2)) {
        list[AType] lflds = getRelFields(t1);
        list[AType] rflds = getRelFields(t2);
        set[AType] failures = { };
        if (size(lflds) != 0 && size(lflds) != 2)
            failures += error(e1, "Relation <fmt(t1)> should have arity of 0 or 2"); 
        if (size(rflds) != 0 && size(rflds) != 2)
            failures += error(e2, "Relation <fmt(t2)> should have arity of 0 or 2");
        if (!comparable(lflds[1],rflds[0]))
            failures += error(exp, "Range of relation <fmt(t1)> must be comparable to domain of relation <fmt(t1)>");
        if (size(failures) > 0) return reportErrors(failures);
        if (size(lflds) == 0 || size(rflds) == 0)
            return arel(atypeList([]));
        else {
            return arel(atypeList([lflds[0],rflds[1]])); 
         }
    }

    if (isListRelType(t1) && isListRelType(t2)) {
        list[AType] lflds = getListRelFields(t1);
        list[AType] rflds = getListRelFields(t2);
        set[AType] failures = { };
        if (size(lflds) != 0 && size(lflds) != 2)
            failures += error(e1, "List relation <fmt(t1)> should have arity of 0 or 2"); 
        if (size(rflds) != 0 && size(rflds) != 2)
            failures += error(e2, "List relation <fmt(t2)> should have arity of 0 or 2");
        if (!comparable(lflds[1],rflds[0]))
            failures += error(exp, "Range of list relation <fmt(t1)> must be comparable to domain of list relation <fmt(t1)>");
        if (size(failures) > 0) return reportErrors(failures);
        if (size(lflds) == 0 || size(rflds) == 0)
            return alrel(atypeList([]));
        else {
            return alrel(atypeList([lflds[0], rflds[1]])); 
        }
    }
    
    if (isFunctionType(t1) && isFunctionType(t2)) {
        compositeArgs = atypeList(getFunctionArgumentTypes(t2));
        compositeRet = getFunctionReturnType(t1);
        linkingArgs = getFunctionArgumentTypes(t1);
        
        // For f o g, f should have exactly one formal parameter
        if (size(linkingArgs) != 1) {
            reportError(current, "In a composition of two functions the leftmost function must have exactly one formal parameter.");
        }
        
        // and, that parameter must be of a type that a call with the return type of g would succeed
        linkingArg = linkingArgs[0];
        rightReturn = getFunctionReturnType(t2);
        if (!subtype(rightReturn, linkingArg)) {
            reportError(current, "The return type of the right-hand function, <fmt(rightReturn)>, cannot be passed to the left-hand function, which expects type <fmt(linkingArg)>");          
        }
        
        // If both of those pass, the result type is a function with the args of t2 and the return type of t1
        rt = afunc(compositeRet, compositeArgs,[]);
        return return rt;         
    }

   reportError(current, "Composition not defined for <fmt(t1)> and <fmt(t2)>");
}

// ---- product

void collect(current: (Expression) `<Expression lhs> * <Expression rhs>`, TBuilder tb){
    tb.calculate("product", current, [lhs, rhs],  
       AType(){ return binaryOp("product", computeProductType, current, getType(lhs), getType(rhs)); });
    collect(lhs, rhs, tb); 
}

AType computeProductType(Tree current, AType t1, AType t2){   
    if(isNumericType(t1) && isNumericType(t2)) return numericArithTypes(t1, t2);
    
    if (isListType(t1) && isListType(t2))
        return makeListType(atuple(atypeList([getListElementType(t1),getListElementType(t2)])));
    if (isRelType(t1) && isRelType(t2))
        return arel(atypeList([getRelElementType(t1),getRelElementType(t2)]));
    if (isListRelType(t1) && isListRelType(t2))
        return alrel(atypeList([getListRelElementType(t1),getListRelElementType(t2)]));
    if (isSetType(t1) && isSetType(t2))
        return arel(atypeList([getSetElementType(t1),getSetElementType(t2)]));
    
    reportError(current, "Product not defined on <fmt(t1)> and <fmt(t2)>");
}

// ---- join

void collect(current: (Expression) `<Expression lhs> join <Expression rhs>`, TBuilder tb){
    tb.calculate("join", current, [lhs, rhs], 
       AType(){ return binaryOp("join", computeJoinType, current, getType(lhs), getType(rhs)); });
    collect(lhs, rhs, tb); 
}

AType computeJoinType(Tree current, AType t1, AType t2){  
    if ((isRelType(t1) && isRelType(t2)) || (isListRelType(t1) && isListRelType(t2))) {
       bool isRel = isRelType(t1);
        list[AType] lflds = isRel ? getRelFields(t1) : getListRelFields(t1);
        list[AType] rflds = isRel ? getRelFields(t2) : getListRelFields(t2);
       
        // If possible, we want to maintain the field names; check here to see if that
        // is possible. We can when 1) both relations use field names, and 2) the names
        // used are distinct.
        list[str] llabels = isRel ? getRelFieldNames(t1) : getListRelFieldNames(t1);
        list[str] rlabels = isRel ? getRelFieldNames(t2) : getListRelFieldNames(t2);
        
        set[str] labelSet = toSet(llabels) + toSet(rlabels);
        flds = atypeList(lflds+rflds);
        if (size(llabels) == size(lflds) && size(rlabels) == size(rflds) && 
            size(labelSet) == size(llabels) + size(rlabels)) {  
            return (isRel ? arel(flds) : alrel(flds));
        } else {
            return isRel ? arel(flds) : alrel(flds); 
        }
    }

    if (isRelType(t1) && isSetType(t2))
        return arel( atypeList(getRelFields(t1) + getSetElementType(t2)) );
    
    if (isSetType(t1) && isRelType(t2))
        return arel( atypeList(getSetElementType(t1) + getRelFields(t2)) );
    
    if (isListRelType(t1) && isListType(t2))
        return alrel( atypeList(getListRelFields(t1) + getListElementType(t2)) );
    
    if (isListType(t1) && isListRelType(t2))
        return alrel( atypeList(getListElementType(t1) +getListRelFields(t2)) );
    
    if (isListType(t1) && isListType(t2))
        return alrel( atypeList(getListElementType(t1), getListElementType(t2))) ;
    
    if (isSetType(t1) && isSetType(t2))
        return arel( atypeList([getSetElementType(t1), getSetElementType(t2)]) );
    
    reportError(current, "Join not defined for <fmt(t1)> and <fmt(t2)>");
} 

// ---- remainder

void collect(current: (Expression) `<Expression lhs> % <Expression rhs>`, TBuilder tb){
    tb.calculate("remainder", current, [lhs, rhs],
        AType(){ return binaryOp("remainder", computeRemainderType, current, getType(lhs), getType(rhs));
                //t1 = getType(lhs); t2 = getType(rhs);
                // if(isIntType(t1) && isIntType(t2)) return lub(t1, t2);
                // reportError(current, "Remainder not defined on <fmt(t1)> and <fmt(t2)>");
        });
    collect(lhs, rhs, tb); 
}

AType computeRemainderType(Tree current, AType t1, AType t2){
    if(isIntType(t1) && isIntType(t2)) return aint();
    reportError(current, "Remainder not defined on <fmt(t1)> and <fmt(t2)>");
}

// ---- division

void collect(current: (Expression) `<Expression lhs> / <Expression rhs>`, TBuilder tb){
    tb.calculate("division", current, [lhs, rhs], 
       AType(){ return binaryOp("division", computeDivisionType, current, getType(lhs), getType(rhs));  });
    collect(lhs, rhs, tb); 
}

AType computeDivisionType(Tree current, AType t1, AType t2){
    if(isNumericType(t1) && isNumericType(t2)) return numericArithTypes(t1, t2);
    reportError(current, "Division not defined on <fmt(t1)> and <fmt(t2)>");
}

// ---- intersection

void collect(current: (Expression) `<Expression lhs> & <Expression rhs>`, TBuilder tb){
    tb.calculate("intersection", current, [lhs, rhs], 
       AType() { return binaryOp("intersection", computeIntersectionType, current, getType(lhs), getType(rhs)); });
    collect(lhs, rhs, tb);
}

AType computeIntersectionType(Tree current, AType t1, AType t2){  
    if ( ( isListRelType(t1) && isListRelType(t2) ) || 
         ( isListType(t1) && isListType(t2) ) || 
         ( isRelType(t1) && isRelType(t2) ) || 
         ( isSetType(t1) && isSetType(t2) ) || 
         ( isMapType(t1) && isMapType(t2) ) )
    {
        if (!comparable(t1,t2))
            reportError(current, "Types <fmt(t1)> and <fmt(t2)> are not comparable");
            
        if (subtype(t2, t1))
            return t2;
            
        if (subtype(t1, t2))
            return t1;
            
        if (isListRelType(t1)) return makeListRelType(makeVoidType(),makeVoidType());
        if (isListType(t1)) return makeListType(makeVoidType());
        if (isRelType(t1)) return makeRelType(makeVoidType(), makeVoidType());
        if (isSetType(t1)) return makeSetType(makeVoidType());
        if (isMapType(t1)) return makeMapType(makeVoidType(),makeVoidType());
    }
    reportError(current, "Intersection not defined on <fmt(t1)> and <fmt(t2)>");
}

// ---- addition

void collect(current: (Expression) `<Expression lhs> + <Expression rhs>`, TBuilder tb){
    tb.calculate("addition", current, [lhs, rhs], AType() { 
        return computeAdditionType(current, getType(lhs), getType(rhs)); 
        });
    collect(lhs, rhs, tb); 
}

default AType computeAdditionType(Tree current, AType t1, AType t2) {

    t1 = instantiate(t1);
    t2 = instantiate(t2);
    if(!(isFullyInstantiated(t1) && isFullyInstantiated(t2))){
       throw TypeUnavailable();
    }   
    
    if(isNumericType(t1) && isNumericType(t2)) return numericArithTypes(t1, t2);
    
    if (isStrType(t1) && isStrType(t2))
        return astr();
    if (isBoolType(t1) && isBoolType(t2))
        return abool();
    if (isLocType(t1) && isLocType(t2))
        return aloc();
    if (isLocType(t1) && isStrType(t2))
        return aloc();
        
     if (isTupleType(t1) && isTupleType(t2)) {
         if (tupleHasFieldNames(t1) && tupleHasFieldNames(t2)) {
            tflds1 = getTupleFields(t1);
            tflds2 = getTupleFields(t2);
            tnms1  = getTupleFieldNames(t1);
            tnms2  = getTupleFieldNames(t2);
            
            if (size(toSet(tnms1 + tnms2)) == size(tflds1+tflds2)) {
                return makeTupleType(tflds1+tflds2);
             } else {
                return makeTupleType(getTupleFieldTypes(t1) + getTupleFieldTypes(t2));
             }
         } else {        
            return makeTupleType(getTupleFieldTypes(t1) + getTupleFieldTypes(t2));
         }
     } 
       
    if (isListType(t1) && isListType(t2))
        return lub(t1,t2);
    if (isSetType(t1) && isSetType(t2))
        return lub(t1,t2);
    if (isMapType(t1) && isMapType(t2))
        return lub(t1,t2);
        
    if (isListType(t1) && !isContainerType(t2))
        return makeListType(lub(getListElementType(t1),t2));
    if (isSetType(t1) && !isContainerType(t2)) // Covers relations too
        return makeSetType(lub(getSetElementType(t1),t2));
    if (isBagType(t1) && !isContainerType(t2))
        return abag(lub(getBagElementType(t1),t2));
        
    if (isListType(t2) && !isContainerType(t1))
        return makeListType(lub(t1,getListElementType(t2)));
    if (isSetType(t2) && !isContainerType(t1)) // Covers relations too
        return makeSetType(lub(t1,getSetElementType(t2)));
    if (isBagType(t2) && !isContainerType(t1))
        return abag(lub(t1,getBagElementType(t2)));
        
    if (isListType(t1))
        return makeListType(lub(getListElementType(t1),t2));
    if (isSetType(t1)) // Covers relations too
        return makeSetType(lub(getSetElementType(t1),t2));
    if (isBagType(t1))
        return abag(lub(getBagElementType(t1),t2));
    
    // TODO: Can we also add together constructor types?
    // TODO: cloc is arbitrary, can we do better?
    cloc = getLoc(current);
    if (isFunctionType(t1)){
        if(isFunctionType(t2))
            return overloadedAType({<cloc, functionId(), t1>, <cloc, functionId(), t2>});
        else if(overloadedAType(rel[Key, IdRole, AType] overloads) := t2){
            return overloadedAType(overloads + <cloc, functionId(), t1>);
        }
    } else if(overloadedAType(rel[Key, IdRole, AType] overloads1)  := t1){
        if(isFunctionType(t2))
           return overloadedAType(overloads + <cloc, functionId(), t2>);
        else if(overloadedAType(rel[Key, IdRole, AType] overloads2) := t2){
            return overloadedAType(overloads1 + overloads2);
        }
    }
    
    reportError(current, "Addition not defined on <fmt(t1)> and <fmt(t2)>");
}

// ---- subtraction

void collect(current: (Expression) `<Expression lhs> - <Expression rhs>`, TBuilder tb){
    tb.calculate("subtraction", current, [lhs, rhs], 
       AType() { return binaryOp("subtraction", computeSubtractionType, current, getType(lhs), getType(rhs)); });
    collect(lhs, rhs, tb); 
}

AType computeSubtractionType(Tree current, AType t1, AType t2) { 
    
    if(isNumericType(t1) && isNumericType(t2)){
        return numericArithTypes(t1, t2);
    }
    if(isListType(t1) && isListType(t2)){
        if(comparable(getListElementType(t1),getListElementType(t2))) return t1;
        reportError(current, "<isListRelType(t1) ? "List Relation" : "List"> of type <fmt(t1)> could never contain elements of second <isListRelType(t2) ? "List Relation" : "List"> type <fmt(t2)>");
    }
    
    if(isListType(t1)){
        if(comparable(getListElementType(t1),t2)) return t1;
        reportError(current, "<isListRelType(t1) ? "List Relation" : "List"> of type <fmt(t1)> could never contain elements of type <fmt(t2)>");
    }
    if(isSetType(t1) && isSetType(t2)){
        if(comparable(getSetElementType(t1),getSetElementType(t2))) return t1;
        reportError(current, "<isRelType(t1) ? "Relation" : "Set"> of type <fmt(t1)> could never contain elements of second <isListRelType(t2) ? "Relation" : "Set"> type <fmt(t2)>");
    }
    if(isSetType(t1)){
        if(comparable(getSetElementType(t1),t2)) return t1;
        reportError(current, "<isRelType(t1) ? "Relation" : "Set"> of type <fmt(t1)> could never contain elements of type <fmt(t2)>");
    }

    if(isMapType(t1)){
        if(comparable(t1, t2)) return t1;
        reportError(current, "Map of type <fmt(t1)> could never contain a sub-map of type <fmt(t2)>");
    }
    
    reportError(current, "Subtraction not defined on <fmt(t1)> and <fmt(t2)>");
}

// ---- appendAfter

void collect(current: (Expression) `<Expression lhs> \<\< <Expression rhs>`, TBuilder tb){
    tb.calculate("append after", current, [lhs, rhs],
        AType(){ return binaryOp("append after", computeAppendAfterType, current, getType(lhs), getType(rhs)); });
    collect(lhs, rhs, tb); 
}

AType computeAppendAfterType(Tree current, AType t1, AType t2) { 
    if (isListType(t1)) {
       return makeListType(lub(getListElementType(t1),t2));
    }
    reportError(current, "Expected a list type, not type <fmt(t1)>");
}

// ---- insertBefore

void collect(current: (Expression) `<Expression lhs> \>\> <Expression rhs>`, TBuilder tb){
    tb.calculate("insert before", current, [lhs, rhs],
       AType(){ return binaryOp("insert before", computeInsertBeforeType, current, getType(lhs), getType(rhs)); });
    collect(lhs, rhs, tb); 
}

AType computeInsertBeforeType(Tree current, AType t1, AType t2) { 
    if (isListType(t2)) {
        return makeListType(lub(getListElementType(t2),t1));
    }
     reportError(current, "Expected a list type, not type <fmt(t2)>");
}

// ---- modulo

void collect(current: (Expression) `<Expression lhs> mod <Expression rhs>`, TBuilder tb){
    tb.calculate("modulo", current, [lhs, rhs],
       AType(){ return binaryOp("modulo", computeModuloType, current, getType(lhs), getType(rhs)); });
    collect(lhs, rhs, tb); 
}

AType computeModuloType(Tree current, AType t1, AType t2) { 
    if (isIntType(t1) && isIntType(t2)) {
        return aint();
    }
    reportError(current, "Modulo not defined on <fmt(t1)> and <fmt(t2)>");
}

// ---- notin

void collect(current: (Expression) `<Expression lhs> notin <Expression rhs>`, TBuilder tb){
    tb.calculate("notin", current, [lhs, rhs], 
       AType () { return binaryOp("notin", computeInType, current, getType(lhs), getType(rhs)); });
    collect(lhs, rhs, tb); 
}

AType computeInType(Tree current, AType t1, AType t2){
    if (isRelType(t2)) {
        et = getRelElementType(t2);
        if (comparable(t1,et)) return abool();
        reportError(current, "Cannot compare <fmt(t1)> with element type of <fmt(t2)>");
    } else if (isSetType(t2)) {
        et = getSetElementType(t2);
        if (comparable(t1,et)) return abool();
        reportError(current, "Cannot compare <fmt(t1)> with element type of <fmt(t2)>");
    } else if (isMapType(t2)) {
        et = getMapDomainType(t2);
        if (comparable(t1,et)) return abool();
        reportError(current, "Cannot compare <fmt(t1)> with domain type of <fmt(t2)>");
    } else if (isListRelType(t2)) {
        et = getListRelElementType(t2);
        if (comparable(t1,et)) return abool();
        reportError(current, "Cannot compare <fmt(t1)> with element type of <fmt(t2)>");
    } else if (isListType(t2)) {
        et = getListElementType(t2);
        if (comparable(t1,et)) return abool();
        reportError(current, "Cannot compare <fmt(t1)> with element type of <fmt(t2)>");
    } else {
        reportError(current, "`in` or `notin` not defined for <fmt(t1)> and <fmt(t2)>");
    }
}

// ---- in

void collect(current: (Expression) `<Expression lhs> in <Expression rhs>`, TBuilder tb){
    tb.calculate("in", current, [lhs, rhs], 
       AType() { return binaryOp("in", computeInType, current, getType(lhs), getType(rhs)); });
    collect(lhs, rhs, tb); 
}

// ---- comparisons >=, <=, <, >, ==, !=

void collect(current: (Expression) `<Expression lhs> \>= <Expression rhs>`, TBuilder tb)
    = checkComparisonOp("\>=", current, tb);
    
void collect(current: (Expression) `<Expression lhs> \<= <Expression rhs>`, TBuilder tb)
    = checkComparisonOp("\<=", current, tb);
    
void collect(current: (Expression) `<Expression lhs> \> <Expression rhs>`, TBuilder tb)
    = checkComparisonOp("\>", current, tb);
    
void collect(current: (Expression) `<Expression lhs> \< <Expression rhs>`, TBuilder tb)
    = checkComparisonOp("\<", current, tb);

void collect(current: (Expression) `<Expression lhs> == <Expression rhs>`, TBuilder tb)
    = checkComparisonOp("==", current, tb);

void collect(current: (Expression) `<Expression lhs> != <Expression rhs>`, TBuilder tb)
    = checkComparisonOp("!=", current, tb);

void checkComparisonOp(str op, Expression current, TBuilder tb){
    tb.calculateEager("comparison <fmt(op)>", current, [current.lhs, current.rhs],
       AType (){ return binaryOp(op, computeComparisonType, current, getType(current.lhs), getType(current.rhs)); });
    collect([current.lhs, current.rhs], tb);
}

AType computeComparisonType(Tree current, AType t1, AType t2){
    if(t1.label?) t1 = unset(t1, "label");
    if(t2.label?) t2 = unset(t2, "label");
    if(comparable(t1, t2) || (isNumericType(t1) && isNumericType(t2)))
       return abool();
        
    if(t1 == avoid() || t2 == avoid())
       reportError(current, "Comparison not defined on <fmt(t1)> and <fmt(t2)>");
        
    if (isListRelType(t1) && isListRelType(t2) && comparableOrNum(getListRelElementType(t1),getListRelElementType(t2)))
        return abool();
    if (isListType(t1) && isListType(t2) && comparableOrNum(getListElementType(t1),getListElementType(t2)))
        return abool();
    if (isMapType(t1) && isMapType(t2) && comparableOrNum(getMapDomainType(t1),getMapDomainType(t2)) && comparableOrNum(getMapRangeType(t1),getMapRangeType(t2)))
        return abool();
    if (isRelType(t1) && isRelType(t2) && comparableOrNum(getRelElementType(t1),getRelElementType(t2)))
        return abool();
    if (isSetType(t1) && isSetType(t2) && comparableOrNum(getSetElementType(t1),getSetElementType(t2)))
        return abool();
    if (isTupleType(t1) && isTupleType(t2))
        return abool();
        
    if (isValueType(t1) || isValueType(t2))
        return abool();
    
    reportError(current, "Comparison not defined on <fmt(t1)> and <fmt(t2)>");
}
    
// ---- ifDefined

void collect(current: (Expression) `<Expression e1> ? <Expression e2>`, TBuilder tb) {    
    tb.calculate("if defined", current, [e1, e2], AType(){ return lub(getType(e1), getType(e2)); });
    collect(e1, e2, tb);
}

// ---- noMatch

void collect(current: (Expression) `<Pattern pat> !:= <Expression expression>`, TBuilder tb){
    computeMatchPattern(current, pat, "!:=", expression, tb);
}
// ---- match

void collect(current: (Expression) `<Pattern pat> := <Expression expression>`, TBuilder tb){
    computeMatchPattern(current, pat, ":=", expression, tb);
}

void computeMatchPattern(Expression current, Pattern pat, str operator, Expression expression, TBuilder tb){
    scope = tb.getScope();
    tb.calculateEager("match", current, [expression],
        AType () {
            subjectType = getType(expression);
            patType = getPatternType(pat, subjectType, scope);
            instantiate(subjectType);
            if(!isFullyInstantiated(patType) || !isFullyInstantiated(subjectType)){
                unify(patType, subjectType) || reportError(pat, "Type of pattern could not be computed");
                ipatType = instantiate(patType);
                if(tvar(src) := patType) fact(src, ipatType);
                patType = ipatType;
                isubjectType = instantiate(subjectType);
                //if(tvar(src) := subjectType) fact(src, isubjectType);
                subjectType = isubjectType;
                keepBindings(getLoc(pat)); // <===
            }
            comparable(patType, subjectType) || reportError(current, "Pattern should be comparable with <fmt(subjectType)>, found <fmt(patType)>");
            return abool();
        });
    tb.push(patternContainer, "match");
    collect(pat, tb);
    tb.pop(patternContainer);
    collect(expression, tb);
}

// ---- enumerator

void collect(current: (Expression) `<Pattern pat> \<- <Expression expression>`, TBuilder tb){
    scope = tb.getScope();
    tb.calculateEager("enumeration", current, [expression],
       AType () { 
             exprType = getType(expression);
             elmType = avalue();
             elmType = computeEnumeratorElementType(current, exprType); 
             patType = getPatternType(pat, elmType, scope);   
             
             if(!isFullyInstantiated(patType) || !isFullyInstantiated(elmType)){
                unify(patType, elmType) || reportError(pat, "Type of pattern could not be computed");
                ipatType = instantiate(patType);
                if(tvar(src) := patType) fact(src, ipatType);
                patType = ipatType;
                ielmType = instantiate(elmType);
                if(tvar(src) := elmType) fact(src, ielmType);
                elmType = ielmType;
                //clearBindings(); // <===
             }  else {
                    fact(pat, patType);
             }     
             comparable(patType, elmType) || reportError(pat, "Pattern of type <fmt(patType)> cannot be used to enumerate over <fmt(exprType)>");
             return abool();
           });
    collect(pat, expression, tb);
}

@doc{Check the types of Rascal expressions: Enumerator}
AType computeEnumeratorElementType(Expression current, AType etype) {
    // TODO: For concrete lists, what should we use as the type?
    // TODO: For nodes, ADTs, and tuples, would it be better to use the lub of all the possible types?

//println("computeEnumeratorElementType: <etype>");
     if(!isFullyInstantiated(etype)) throw TypeUnavailable();
     etype = instantiate(etype);
    
    if (isSetType(etype)) {
        return getSetElementType(etype);
    } else if (isListType(etype)) {
        return getListElementType(etype);
    } else if (isMapType(etype)) {
        return getMapDomainType(etype);
    } else if (isADTType(etype) || isTupleType(etype) || isNodeType(etype)) {
        return avalue();
    } else if (isNonTerminalIterType(etype)) {
        return getNonTerminalIterElement(etype);
    } else if (isNonTerminalOptType(etype)) {
        return getNonTerminalOptType(etype);
    } else if(overloadedAType(rel[Key, IdRole, AType] overloads) := etype){
        for(<key, role, tp> <- overloads, isEnumeratorType(tp)){
            try {
                return computeEnumeratorElementType(current, tp);
            } catch checkFailed(set[Message] msgs): {
                ; // do nothing and try next overload
            }
        }
    } 
    reportError(current, "Type <fmt(etype)> is not enumerable");
}

// TODO scoping rules in Boolean operators!
// ---- implication

void collect(current: (Expression) `<Expression lhs> ==\> <Expression rhs>`, TBuilder tb){
    tb.fact(current, abool());
   
    tb.requireEager("implication", current, [lhs, rhs],
        (){ unify(abool(), getType(lhs)) || reportError(lhs, "Argument of ==\> should be `bool`, found <fmt(lhs)>");
            //clearBindings();
            unify(abool(), getType(rhs)) || reportError(rhs, "Argument of ==\> should be `bool`, found <fmt(rhs)>");
            //clearBindings();
          });
    collect(lhs, rhs, tb);
}

// ---- equivalence

void collect(current: (Expression) `<Expression lhs> \<==\> <Expression rhs>`, TBuilder tb){
    //tb.fact(current, abool());
   
    tb.calculateEager("equivalence", current, [lhs, rhs],
        AType (){ unify(abool(), getType(lhs)) || reportError(lhs, "Argument of \<==\> should be `bool`, found <fmt(lhs)>");
                  //clearBindings();
                  unify(abool(), getType(rhs)) || reportError(rhs, "Argument of \<==\> should be `bool`, found <fmt(rhs)>");
                  //clearBindings();
                  return abool();
                });
    collect(lhs, rhs, tb);
}

// ---- and

void collect(current: (Expression) `<Expression lhs> && <Expression rhs>`, TBuilder tb){
    tb.fact(current, abool());
   
    tb.requireEager("and", current, [lhs, rhs],
        (){ 
            unify(abool(), getType(lhs)) || reportError(lhs, "Argument of && should be `bool`, found <fmt(lhs)>");
            //clearBindings();
            unify(abool(), getType(rhs)) || reportError(rhs, "Argument of && should be `bool`, found <fmt(rhs)>");
            //clearBindings();
          });
    collect(lhs, rhs, tb);
}

// ---- or

void collect(current: (Expression) `<Expression lhs> || <Expression rhs>`, TBuilder tb){
    tb.fact(current, abool());
      
    tb.requireEager("or", current, [lhs, rhs],
        (){ unify(abool(), getType(lhs)) || reportError(lhs, "Argument of || should be `bool`, found <fmt(lhs)>");
            unify(abool(), getType(rhs)) || reportError(rhs, "Argument of || should be `bool`, found <fmt(rhs)>");
          });
          
    // Check that the names introduced in lhs and rhs are the same    
    
    namesBeforeOr = tb.getStack(patternNames);
    collect(lhs, tb);
    namesAfterLhs = tb.getStack(patternNames);
    
    // Restore patternNames
    tb.clearStack(patternNames);
    for(nm <- reverse(namesBeforeOr)) tb.push(patternNames, nm);
    
    // Trick 1: wrap rhs in a separate scope to avoid double declarations with names introduced in lhs
    // Trick 2: use "current" as scope (to avoid clash with scope created by rhs)
    tb.enterScope(lhs);
        collect(rhs, tb);
    tb.leaveScope(lhs);
    namesAfterRhs = tb.getStack(patternNames);
  
    missingInLhs = namesAfterRhs - namesAfterLhs;
    missingInRhs = namesAfterLhs - namesAfterRhs;
    //if(!isEmpty(missingInLhs)) tb.reportError(lhs, "Left argument of `||` should also introduce <fmt(missingInLhs)>");
    //if(!isEmpty(missingInRhs)) tb.reportError(rhs, "Right argument of `||` should also introduce <fmt(missingInRhs)>");
}

// ---- if expression

void collect(current: (Expression) `<Expression condition> ? <Expression thenExp> : <Expression elseExp>`, TBuilder tb){
    tb.enterScope(condition);   // thenExp may refer to variables defined in conditions; elseExp may not
        storeExcludeUse(condition, elseExp, tb);            // variable occurrences in elseExp may not refer to variables defined in condition
        
        tb.calculate("if expression", current, [condition, thenExp, elseExp],
            AType (){
                unify(abool(), getType(condition)) || reportError(condition, "Condition should be `bool`, found <fmt(condition)>");
                //clearBindings();
                //checkConditions([condition]);
                return lub(getType(thenExp), getType(thenExp));
            });
        beginPatternScope("conditions", tb);
        collect(condition, tb);
        endPatternScope(tb);
        collect(thenExp, elseExp, tb);
    tb.leaveScope(condition); 
}