<?php

class __Mustache_d387acfd436edfe99514bdd98c94daf9 extends Mustache_Template
{
    private $lambdaHelper;

    public function renderInternal(Mustache_Context $context, $indent = '')
    {
        $this->lambdaHelper = new Mustache_LambdaHelper($this->mustache, $context);
        $buffer = '';

        $buffer .= $indent . '<button class="section-modchooser section-modchooser-link ';
        $value = $context->find('hasactionlinks');
        if (empty($value)) {
            
            $buffer .= 'btn add-content d-flex justify-content-center align-items-center p-1 icon-no-margin';
        }
        $value = $context->find('hasactionlinks');
        $buffer .= $this->section0a1771115ca2346fa1002d550cdf4cc7($context, $indent, $value);
        $buffer .= '"
';
        $buffer .= $indent . '    data-action="open-chooser"
';
        $buffer .= $indent . '    data-sectionnum="';
        $value = $this->resolveValue($context->find('sectionnum'), $context);
        $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
        $buffer .= '"
';
        $buffer .= $indent . '    ';
        $value = $context->find('sectionreturn');
        $buffer .= $this->section96e5910d1aec067f644ed51986551f8f($context, $indent, $value);
        $buffer .= '
';
        $value = $context->find('modid');
        $buffer .= $this->sectionB706f0b854d43b2996d91731910d4e3f($context, $indent, $value);
        $buffer .= $indent . '>
';
        $value = $context->find('hasactionlinks');
        if (empty($value)) {
            
            $value = $context->find('modid');
            $buffer .= $this->section94157698efd8acfef2693994796e28a1($context, $indent, $value);
            $value = $context->find('modid');
            if (empty($value)) {
                
                $buffer .= $indent . '            <div class="px-1">
';
                $buffer .= $indent . '                ';
                $value = $context->find('pix');
                $buffer .= $this->section9b089e00077ec061918a3e4dd2d05479($context, $indent, $value);
                $buffer .= '
';
                $buffer .= $indent . '                <span class="activity-add-text pe-1">';
                $value = $context->find('str');
                $buffer .= $this->section037ed759c395d547607491573906432c($context, $indent, $value);
                $buffer .= '</span>
';
                $buffer .= $indent . '            </div>
';
            }
        }
        $value = $context->find('hasactionlinks');
        $buffer .= $this->section3a6bf4e597480bb0cdc922bb187fd821($context, $indent, $value);
        $buffer .= $indent . '</button>
';

        return $buffer;
    }

    private function section0a1771115ca2346fa1002d550cdf4cc7(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = 'dropdown-item';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= 'dropdown-item';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section96e5910d1aec067f644ed51986551f8f(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = 'data-sectionreturnnum="{{.}}"';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= 'data-sectionreturnnum="';
                $value = $this->resolveValue($context->last(), $context);
                $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                $buffer .= '"';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function sectionAcd66ef23857ba2b241b6f8f23ef69c2(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = ' {{activityname}} ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= ' ';
                $value = $this->resolveValue($context->find('activityname'), $context);
                $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                $buffer .= ' ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section9a212121c7b2d8091fbf9fada23ff817(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = 'insertresourceoractivitybefore, core, { "activityname": {{#quote}} {{activityname}} {{/quote}} } ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= 'insertresourceoractivitybefore, core, { "activityname": ';
                $value = $context->find('quote');
                $buffer .= $this->sectionAcd66ef23857ba2b241b6f8f23ef69c2($context, $indent, $value);
                $buffer .= ' } ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section037ed759c395d547607491573906432c(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = 'addresourceoractivity, core';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= 'addresourceoractivity, core';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function sectionB706f0b854d43b2996d91731910d4e3f(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = '
        data-beforemod="{{modid}}"
        aria-label="{{#str}}insertresourceoractivitybefore, core, { "activityname": {{#quote}} {{activityname}} {{/quote}} } {{/str}}"
        tabindex="0"
        title="{{#str}}addresourceoractivity, core{{/str}}"
    ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= $indent . '        data-beforemod="';
                $value = $this->resolveValue($context->find('modid'), $context);
                $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                $buffer .= '"
';
                $buffer .= $indent . '        aria-label="';
                $value = $context->find('str');
                $buffer .= $this->section9a212121c7b2d8091fbf9fada23ff817($context, $indent, $value);
                $buffer .= '"
';
                $buffer .= $indent . '        tabindex="0"
';
                $buffer .= $indent . '        title="';
                $value = $context->find('str');
                $buffer .= $this->section037ed759c395d547607491573906432c($context, $indent, $value);
                $buffer .= '"
';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section9b089e00077ec061918a3e4dd2d05479(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = ' t/add, core ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= ' t/add, core ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section94157698efd8acfef2693994796e28a1(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = '
            {{#pix}} t/add, core {{/pix}}
        ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= $indent . '            ';
                $value = $context->find('pix');
                $buffer .= $this->section9b089e00077ec061918a3e4dd2d05479($context, $indent, $value);
                $buffer .= '
';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section9e5c353b854bb77d0c98472d9d7d9f13(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = ' i/activities, core ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= ' i/activities, core ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function sectionA5efff3c54fdaadf5d0487341be5c9d9(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = 'activityorresource, core';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= 'activityorresource, core';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section3a6bf4e597480bb0cdc922bb187fd821(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = '
        {{#pix}} i/activities, core {{/pix}}{{#str}}activityorresource, core{{/str}}
    ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= $indent . '        ';
                $value = $context->find('pix');
                $buffer .= $this->section9e5c353b854bb77d0c98472d9d7d9f13($context, $indent, $value);
                $value = $context->find('str');
                $buffer .= $this->sectionA5efff3c54fdaadf5d0487341be5c9d9($context, $indent, $value);
                $buffer .= '
';
                $context->pop();
            }
        }
    
        return $buffer;
    }

}
