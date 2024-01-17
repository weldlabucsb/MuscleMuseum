function gE = gaussian_grad(in1,w0,k)
%GAUSSIAN_GRAD
%    GE = GAUSSIAN_GRAD(IN1,W0,K)

%    This function was generated by the Symbolic Math Toolbox version 8.0.
%    07-May-2018 14:32:24

r1 = in1(:,1);
r2 = in1(:,2);
r3 = in1(:,3);
if (r3 == 0.0)
    t0 = r1.*1.0./w0.^2.*exp(-1.0./w0.^2.*(r1.^2+r2.^2)).*-2.0;
else
    t0 = r1.*1.0./w0.^2.*exp(-(1.0./w0.^2.*(r1.^2+r2.^2))./(1.0./k.^2.*r3.^2.*1.0./w0.^4.*4.0+1.0)).*exp(atan((r3.*1.0./w0.^2.*2.0)./k).*1i-k.*r3.*1i-(k.*(r1.^2+r2.^2).*5.0e-1i)./(r3.*(k.^2.*1.0./r3.^2.*w0.^4.*(1.0./4.0)+1.0))).*1.0./(1.0./k.^2.*r3.^2.*1.0./w0.^4.*4.0+1.0).^(3.0./2.0).*-2.0-(k.*r1.*exp(-(1.0./w0.^2.*(r1.^2+r2.^2))./(1.0./k.^2.*r3.^2.*1.0./w0.^4.*4.0+1.0)).*exp(atan((r3.*1.0./w0.^2.*2.0)./k).*1i-k.*r3.*1i-(k.*(r1.^2+r2.^2).*5.0e-1i)./(r3.*(k.^2.*1.0./r3.^2.*w0.^4.*(1.0./4.0)+1.0))).*1.0./sqrt(1.0./k.^2.*r3.^2.*1.0./w0.^4.*4.0+1.0).*1i)./(r3.*(k.^2.*1.0./r3.^2.*w0.^4.*(1.0./4.0)+1.0));
end
if (r3 == 0.0)
    t1 = r2.*1.0./w0.^2.*exp(-1.0./w0.^2.*(r1.^2+r2.^2)).*-2.0;
else
    t1 = r2.*1.0./w0.^2.*exp(-(1.0./w0.^2.*(r1.^2+r2.^2))./(1.0./k.^2.*r3.^2.*1.0./w0.^4.*4.0+1.0)).*exp(atan((r3.*1.0./w0.^2.*2.0)./k).*1i-k.*r3.*1i-(k.*(r1.^2+r2.^2).*5.0e-1i)./(r3.*(k.^2.*1.0./r3.^2.*w0.^4.*(1.0./4.0)+1.0))).*1.0./(1.0./k.^2.*r3.^2.*1.0./w0.^4.*4.0+1.0).^(3.0./2.0).*-2.0-(k.*r2.*exp(-(1.0./w0.^2.*(r1.^2+r2.^2))./(1.0./k.^2.*r3.^2.*1.0./w0.^4.*4.0+1.0)).*exp(atan((r3.*1.0./w0.^2.*2.0)./k).*1i-k.*r3.*1i-(k.*(r1.^2+r2.^2).*5.0e-1i)./(r3.*(k.^2.*1.0./r3.^2.*w0.^4.*(1.0./4.0)+1.0))).*1.0./sqrt(1.0./k.^2.*r3.^2.*1.0./w0.^4.*4.0+1.0).*1i)./(r3.*(k.^2.*1.0./r3.^2.*w0.^4.*(1.0./4.0)+1.0));
end
if (r3 == 0.0)
    t2 = -(1.0./w0.^4.*exp(-1.0./w0.^2.*(r1.^2+r2.^2)).*(k.^2.*w0.^4.*1i+r1.^2.*2.0i+r2.^2.*2.0i-w0.^2.*2.0i))./k;
else
    t2 = -exp(-(1.0./w0.^2.*(r1.^2+r2.^2))./(1.0./k.^2.*r3.^2.*1.0./w0.^4.*4.0+1.0)).*exp(atan((r3.*1.0./w0.^2.*2.0)./k).*1i-k.*r3.*1i-(k.*(r1.^2+r2.^2).*5.0e-1i)./(r3.*(k.^2.*1.0./r3.^2.*w0.^4.*(1.0./4.0)+1.0))).*1.0./sqrt(1.0./k.^2.*r3.^2.*1.0./w0.^4.*4.0+1.0).*(k.*1i-(1.0./w0.^2.*2.0i)./(k.*(1.0./k.^2.*r3.^2.*1.0./w0.^4.*4.0+1.0))-(k.*1.0./r3.^2.*(r1.^2+r2.^2).*5.0e-1i)./(k.^2.*1.0./r3.^2.*w0.^4.*(1.0./4.0)+1.0)+k.^3.*1.0./r3.^4.*w0.^4.*(r1.^2+r2.^2).*1.0./(k.^2.*1.0./r3.^2.*w0.^4.*(1.0./4.0)+1.0).^2.*2.5e-1i)-1.0./k.^2.*r3.*1.0./w0.^4.*exp(-(1.0./w0.^2.*(r1.^2+r2.^2))./(1.0./k.^2.*r3.^2.*1.0./w0.^4.*4.0+1.0)).*exp(atan((r3.*1.0./w0.^2.*2.0)./k).*1i-k.*r3.*1i-(k.*(r1.^2+r2.^2).*5.0e-1i)./(r3.*(k.^2.*1.0./r3.^2.*w0.^4.*(1.0./4.0)+1.0))).*1.0./(1.0./k.^2.*r3.^2.*1.0./w0.^4.*4.0+1.0).^(3.0./2.0).*4.0+1.0./k.^2.*r3.*1.0./w0.^6.*exp(-(1.0./w0.^2.*(r1.^2+r2.^2))./(1.0./k.^2.*r3.^2.*1.0./w0.^4.*4.0+1.0)).*exp(atan((r3.*1.0./w0.^2.*2.0)./k).*1i-k.*r3.*1i-(k.*(r1.^2+r2.^2).*5.0e-1i)./(r3.*(k.^2.*1.0./r3.^2.*w0.^4.*(1.0./4.0)+1.0))).*(r1.^2+r2.^2).*1.0./(1.0./k.^2.*r3.^2.*1.0./w0.^4.*4.0+1.0).^(5.0./2.0).*8.0;
end
gE = [t0,t1,t2];
