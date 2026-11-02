function tolerance = fzeroTolerance(absoluteTolerance, bracket)
%FZEROTOLERANCE fzero TolX that bounds the root error by an absolute tolerance.
%   tolerance = terra.fzeroTolerance(absoluteTolerance, bracket) returns
%   the TolX to pass to fzero on the interval bracket so that the root is
%   located within absoluteTolerance (in the units of x) on both
%   platforms:
%     MATLAB  stops once its bracket is below 4*TolX*max(|x|, 1), so TolX
%             acts as a relative tolerance when |x| > 1;
%     Octave  stops once its bracket is below 2*TolX + 4*|x|*eps.
%   Dividing by 4*max(|x|, 1) over the bracket makes the declared
%   tolerance absolute in both.

    matlabBracketFactor = 4;
    tolerance = absoluteTolerance / (matlabBracketFactor * max([abs(bracket(:)); 1]));
end
